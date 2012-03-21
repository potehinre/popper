-module(websocket_handler).
-export([init/3]).
-export([websocket_init/3, websocket_handle/3,
    websocket_info/3, websocket_terminate/3]).

ws_send(Msg) ->
    self() ! {event, Msg}.

init({tcp, http}, Req, Opts) ->
    {upgrade, protocol, cowboy_http_websocket}.

websocket_init(TransportName, Req, _Opts) ->
    ConnEstablishedMsg = util:pusher_connection_json(<< "pusher:connection_established" >>,[{<< "socket_id" >>, 13}]),
    ws_send(ConnEstablishedMsg),
    {ok, Req, undefined_state}.

websocket_handle({text, Msg}, Req, State) ->
    case mochijson2:decode(Msg) of
	 %%Connection Events
	 {struct,[{<< "event" >>, Event},{<< "data" >>,{struct,Data}}]} ->
	    case Event of
		<<"pusher:subscribe">> ->
			[{<< "channel" >>,ChannelName}, _, {<< "channel_data" >>,ChannelData}] = Data,
			ChanPid = channel_hub:subscribe(ChannelName),
			{struct,[{<<"user_id">>,UserId}, {<<"user_info">>,UserInfo}]} = ChannelData,
			ok = channel:subscribe(ChanPid, self(), UserId, UserInfo),
			RespData = [{<< "presence" >>,{struct,[{<<"ids">>,[1]},{<<"count">>,1}]}}],
			Response = util:pusher_channel_json(<< "pusher_internal:subscription_succeeded" >>, ChannelName, RespData),
		    link(ChanPid),
			ws_send(Response);
		<<"pusher:unsubscribe">> ->
			[{<<"channel">>,ChannelName}] = Data,
			[{_,ChanPid}] = channel_hub:chan_pid_by_name(ChannelName),
			channel:unsubscribe(ChanPid),
			unlink(ChanPid)
	    end;
	%%Channel Events
	{struct,[{<<"event">>,EventName},{<<"data">>,{struct,EventData}},{<<"channel">>,ChannelName}]} ->
		[{_,ChanPid}] = channel_hub:chan_pid_by_name(ChannelName),
		channel:event(ChanPid,EventName,ChannelName,EventData);
	_Ignore ->
		io:format("Incorrect Json:~p ~n",[_Ignore])
    end,
    {ok, Req, State};

websocket_handle(_Data, Req, State) ->
    {ok, Req, State}.

websocket_info({event, Msg}, _Req, _State) ->
    {reply, {text, Msg}, _Req, _State};

websocket_info(_Info, Req, State) ->
    {ok, Req, State}.

websocket_terminate(_Reason, _Req, _State) ->
    ok.
