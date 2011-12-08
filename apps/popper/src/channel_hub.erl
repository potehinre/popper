%%%Author: potehinre
-module(channel_hub).
-behaviour(gen_server).
-export([subscribe/1,unsubscribe/2,start_link/0,init/1,handle_cast/2,handle_call/3,
		 handle_info/2,terminate/2,code_change/3,channel_name_to_pid_info/0,
		 chan_name_by_pid/1,chan_pid_by_name/1]).

subscribe(ChannelName) ->
	gen_server:call(channel_hub,{subscribe,ChannelName}).

unsubscribe(UserPid,ChannelName) ->
	gen_server:cast(channel_hub,{unsubscribe,UserPid,ChannelName}).

channel_name_to_pid_info() ->
	gen_server:call(channel_hub,channel_name_to_pid_info).

%%Server callbacks
start_link() ->
	gen_server:start_link({local,?MODULE},?MODULE,[],[]).

init([]) ->
	process_flag(trap_exit,true),
	ets:new(channel_name_to_pid,[set,named_table]),
	ets:new(channel_pid_to_name,[set,named_table]),
	{ok,no_state}.

add_new_channel(Name, Pid) ->
	ets:insert(channel_name_to_pid,{Name,Pid}),
	ets:insert(channel_pid_to_name,{Pid,Name}).

chan_pid_by_name(Name) ->
	ets:lookup(channel_name_to_pid,Name).

chan_name_by_pid(Pid) when is_pid(Pid) ->
	ets:lookup(channel_pid_to_name,Pid).

handle_cast({unsubscribe,UserPid,ChannelName},State) ->
	Channel = chan_pid_by_name(ChannelName),
	case Channel of
		[{_ChanName,ChanPid}|[]] ->
			channel:unregister_user(ChanPid,UserPid)
	end,
	{noreply,State}.

handle_call({subscribe,ChannelName},_From,State) ->
	Channel = chan_pid_by_name(ChannelName),
	case Channel of
		[] ->
			{ok,Pid} = channel:start_link(),
			add_new_channel(ChannelName,Pid),
			{reply,Pid,State};
		[{_ChanName,ChanPid}] ->
			{reply,ChanPid,State}
	end;

handle_call(channel_name_to_pid_info,_From,State) ->
	{reply,ets:tab2list(channel_name_to_pid),State}.

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