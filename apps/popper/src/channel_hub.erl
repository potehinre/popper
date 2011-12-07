%%%Author: potehinre
-module(channel_hub).
-behaviour(gen_server).
-export([join/1,leave/2,start_link/0,init/1,handle_cast/2,handle_call/3,
		 handle_info/2,terminate/2,code_change/3,channels_info/0]).

join(ChannelName) ->
	gen_server:call(channel_hub,{join,ChannelName}).

leave(UserName,ChannelName) ->
	gen_server:cast(channel_hub,{leave,UserName,ChannelName}).

channels_info() ->
	gen_server:call(channel_hub,channels_info).

%%Server callbacks
start_link() ->
	gen_server:start_link({local,?MODULE},?MODULE,[],[]).

init([]) ->
	process_flag(trap_exit,true),
	ets:new(channels,[set,named_table]),
	{ok,no_state}.

handle_cast({leave,UserName,ChannelName},State) ->
	Channel = ets:lookup(channels,ChannelName),
	case Channel of
		[{_ChanName,ChanPid,_ChanRef}|[]] ->
			channel:unregister_user(ChanPid,UserName)
	end,
	{noreply,State}.

handle_call({join,ChannelName},_From,State) ->
	Channel = ets:lookup(channels,ChannelName),
	case Channel of
		[] ->
			{ok,Pid} = channel:start_link(),
			ets:insert(channels,{ChannelName,Pid}),
			{reply,Pid,State};
		[{_ChanName,ChanPid}|[]] ->
			{reply,ChanPid,State}
	end;

handle_call(channels_info,_From,State) ->
	{reply,ets:tab2list(channels),State}.

handle_info(Info,State) ->
	case Info of
		{'EXIT',Pid,Reason} ->
			io:format("~p channel is down!!!With reason ~p ~n",[Pid,Reason])
	end,
	{noreply,State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.