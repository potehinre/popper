%%% -------------------------------------------------------------------
%%% Author  : potehinre
%%% Description :
%%%
%%% Created : 12.09.2011
%%% -------------------------------------------------------------------
-module(channel).

-behaviour(gen_server).
-export([start_link/0,init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3,
		 broadcast_message/2,register_user/4,unregister_user/2,take_users/1]).

-record(state, {users=orddict:new()}).

%% ====================================================================
%% External functions
%% ====================================================================
register_user(Pid,UserPid,Name,UserInfo) ->
	gen_server:cast(Pid,{register_user,UserPid,Name,UserInfo}).

unregister_user(Pid,UserPid) ->
	gen_server:cast(Pid,{unregister_user,UserPid}).

broadcast_message(Pid,Message) ->
	gen_server:cast(Pid,{broadcast_message,self(),Message}).

take_users(Pid) ->
	[Name || {_,Name} <- gen_server:call(Pid,take_users)].

%% ====================================================================
%% Server functions
%% ====================================================================

start_link() ->
	gen_server:start_link(?MODULE,[],[]).

init([]) ->
	io:format("Chan ~p started ~n",[self()]),
    {ok, #state{}}.

handle_call(take_users,_From, State) ->
	Reply = orddict:to_list(State#state.users),
	{reply, Reply, State}.

handle_cast({broadcast_message,From,Msg}, State) ->
	io:format("Channel received a new  message from ~p ~p ~n", [From,Msg]),
	{PosterName,_Info} = orddict:fetch(From,State#state.users),
	[UserPid ! {msg,PosterName,Msg} || UserPid <- orddict:fetch_keys(State#state.users)],
    {noreply, State};

handle_cast({register_user,Pid,Name,Info}, State) ->
	io:format("New user registered ~p ~n", [Name]),
	NewState = State#state{users=orddict:store(Pid,{Name,Info},State#state.users)},
%	[UserPid ! {newuserlist,[Name || {Pid,Name} <- NewState#state.users]} || UserPid <-orddict:fetch_keys(NewState#state.users)],
	{noreply, NewState};

handle_cast({unregister_user,Pid}, State) ->
	NewState = State#state{users=orddict:erase(Pid, State#state.users)},
	{noreply, NewState}.

handle_info(Info, State) ->
    {noreply, State}.

terminate(Reason, State) ->
    ok.

code_change(OldVsn, State, Extra) ->
    {ok, State}.