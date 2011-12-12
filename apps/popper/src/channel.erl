%%% -------------------------------------------------------------------
%%% Author  : potehinre
%%% Description :
%%%
%%% Created : 12.09.2011
%%% -------------------------------------------------------------------
-module(channel).

-behaviour(gen_server).
-export([start_link/0,init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3,
		 event/4,subscribe/4,take_users/1,unsubscribe/1]).

-record(state, {users=orddict:new()}).

%% ====================================================================
%% External functions
%% ====================================================================
subscribe(Pid,UserPid,Name,UserInfo) ->
	gen_server:call(Pid,{subscribe,UserPid,Name,UserInfo}).

unsubscribe(Pid) ->
	gen_server:cast(Pid,{unsubscribe,self()}).

event(Pid,EventName,ChannelName,EventData) ->
	gen_server:cast(Pid,{event,self(),EventName,ChannelName,EventData}).

take_users(Pid) ->
	[UserInfo || {_,UserInfo} <- gen_server:call(Pid,take_users)].

unregister_user(Pid,State) when is_pid(Pid) ->
	{UserId,_UserInfo} = orddict:fetch(Pid,State#state.users),
	NewState = State#state{users=orddict:erase(Pid, State#state.users)},
	[{_,ChannelName}] = channel_hub:chan_name_by_pid(self()),
	UserData = [{<<"user_id">>,UserId}],
	Json = util:pusher_channel_json(<<"pusher_internal:member_removed">>,ChannelName,UserData),
	[UserPid ! {event,Json} || UserPid <- orddict:fetch_keys(NewState#state.users)],
	{NewState,Json}.

register_user(Pid,UserId,UserInfo,State) when is_pid(Pid) ->
	NewState = State#state{users=orddict:store(Pid,{UserId,UserInfo},State#state.users)},
	[{_,ChannelName}] = channel_hub:chan_name_by_pid(self()),
	UserData = [{<<"user_id">>,UserId},{<<"user_info">>,UserInfo}],
	Json = util:pusher_channel_json(<<"pusher_internal:member_added">>, ChannelName, UserData),
	{NewState,Json}.

broadcast_event(State,Json) ->
	[UserPid ! {event,Json} || UserPid <- orddict:fetch_keys(State#state.users)].

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

handle_call({subscribe,Pid,UserId,UserInfo},_From,State) ->
	{NewState,Json} = register_user(Pid,UserId,UserInfo,State), 
	broadcast_event(NewState,Json),
	Reply = [User  || {_,User} <- orddict:to_list(NewState#state.users)],
	{reply, Reply, NewState}.

handle_cast({event,_From,EventName,ChannelName,EventData}, State) ->
	Json = util:pusher_channel_json(EventName, ChannelName, EventData),
	broadcast_event(State,Json),
    {noreply, State};

handle_cast({unsubscribe,UserPid},State) ->
	{NewState,Json}=unregister_user(UserPid, State),
	broadcast_event(NewState,Json),
	case orddict:size(NewState#state.users) of 
		0 ->  exit(normal);
		_ ->  {noreply, NewState}
	end.

handle_info({'EXIT', Pid, Reason},State) ->
	io:format("user ~p failed with reason ~p ~n",[Pid,Reason]),
	{NewState,Json}=unregister_user(Pid,State),
	broadcast_event(NewState,Json),
	case orddict:size(NewState#state.users) of 
		0 ->  exit(normal);
		_ ->  {noreply, NewState}
	end;	

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(OldVsn, State, Extra) ->
    {ok, State}.