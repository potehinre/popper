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
	process_flag(trap_exit,true),
    {ok, #state{}}.

handle_call(take_users,_From, State) ->
	Reply = orddict:to_list(State#state.users),
	{reply, Reply, State};

handle_call({register_user,Pid,UserId,UserInfo},_From,State) ->
	NewState = State#state{users=orddict:store(Pid,{UserId,UserInfo},State#state.users)},
	[{_,ChannelName}] = channel_hub:chan_name_by_pid(self()),
	UserData = [{<<"user_id">>,UserId},{<<"user_info">>,UserInfo}],
	Json = util:pusher_channel_json(<<"pusher_internal:member_added">>, ChannelName, UserData),
	[UserPid ! {member_added,Json} || UserPid <- orddict:fetch_keys(NewState#state.users)],
	Reply = [User  || {_,User} <- orddict:to_list(NewState#state.users)],
	{reply, Reply, NewState}.

handle_cast({broadcast_event,_From,EventName,ChannelName,EventData}, State) ->
	Json = util:pusher_channel_json(EventName, ChannelName, EventData),
	[UserPid ! {custom_event,Json} || UserPid <- orddict:fetch_keys(State#state.users)],
    {noreply, State};

handle_cast({unregister_user,Pid}, State) ->
	{UserId,_UserInfo} = orddict:fetch(Pid,State#state.users),
	NewState = State#state{users=orddict:erase(Pid, State#state.users)},
	[{_,ChannelName}] = channel_hub:chan_name_by_pid(self()),
	UserData = [{<<"user_id">>,UserId}],
	Json = util:pusher_channel_json(<<"pusher_internal:member_removed">>,ChannelName,UserData),
	[UserPid ! {member_removed,Json} || UserPid <- orddict:fetch_keys(NewState#state.users)],
	{noreply, NewState}.

handle_info({'EXIT', Pid, Reason},State) ->
	io:format("user ~p failed with reason ~p ~n",[Pid,Reason]),
	unregister_user(self(),Pid),
	{noreply, State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(OldVsn, State, Extra) ->
    {ok, State}.