%%% -------------------------------------------------------------------
%%% Author  : potehinre
%%% Description :
%%%
%%% Created : 12.09.2011
%%% -------------------------------------------------------------------
-module(channel).

-behaviour(gen_server).
-export([start_link/0,init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3,
		 broadcast_event/4,register_user/4,unregister_user/2,take_users/1]).

-record(state, {users=orddict:new()}).

%% ====================================================================
%% External functions
%% ====================================================================
register_user(Pid,UserPid,Name,UserInfo) ->
	gen_server:call(Pid,{register_user,UserPid,Name,UserInfo}).

unregister_user(Pid,UserPid) ->
	gen_server:cast(Pid,{unregister_user,UserPid}).

broadcast_event(Pid,EventName,ChannelName,EventData) ->
	gen_server:cast(Pid,{broadcast_event,self(),EventName,ChannelName,EventData}).

take_users(Pid) ->
	[UserInfo || {_,UserInfo} <- gen_server:call(Pid,take_users)].
	

%% ====================================================================
%% Server functions
%% ====================================================================

start_link() ->
	gen_server:start_link(?MODULE,[],[]).

init([]) ->
	io:format("Chan ~p started ~n",[self()]),
	process_flag(trap_exit,true),
    {ok, #state{}}.

handle_call(take_users,_From, State) ->
	Reply = orddict:to_list(State#state.users),
	{reply, Reply, State};

handle_call({register_user,Pid,Name,Info},_From,State) ->
	NewState = State#state{users=orddict:store(Pid,{Name,Info},State#state.users)},
	[{_,ChannelName}] = channel_hub:chan_name_by_pid(self()),
	[UserPid ! {member_added,{Name,Info,ChannelName}} || UserPid <- orddict:fetch_keys(NewState#state.users)],
	io:format("New user registered ~p ~n", [Name]),
	Reply = [User  || {_,User} <- orddict:to_list(NewState#state.users)],
	{reply, Reply, NewState}.

handle_cast({broadcast_event,From,EventName,ChannelName,EventData}, State) ->
	io:format("Channel received a new  message from ~p ~p ~n", [From,EventData]),
	[UserPid ! {custom_event,{EventName,ChannelName,EventData}} || UserPid <- orddict:fetch_keys(State#state.users)],
    {noreply, State};

handle_cast({unregister_user,Pid}, State) ->
	{Name,_Info} = orddict:fetch(Pid,State#state.users),
	NewState = State#state{users=orddict:erase(Pid, State#state.users)},
	[{_,ChannelName}] = channel_hub:chan_name_by_pid(self()),
	[UserPid ! {member_removed,{Name,ChannelName}} || UserPid <- orddict:fetch_keys(NewState#state.users)],
	io:format("user unregistered ~p ~n", [_Info]),
	{noreply, NewState}.

handle_info({'EXIT', Pid, Reason},State) ->
	io:format("user ~p failed with reason ~p ~n",[Pid,Reason]),
	unregister_user(self(),Pid),
	{noreply, State};

handle_info(Info, State) ->
    {noreply, State}.

terminate(Reason, State) ->
    ok.

code_change(OldVsn, State, Extra) ->
    {ok, State}.