-module(server).
-export([start_link/1,stop/0]).

start_link(Port) ->
	    misultin:start_link([{port,Port},
				 {name, misultin_ws},
				 {acceptors_poolsize,1000},
				 {max_connections,100000},
				 {loop, fun(Req)   -> handle_http(Req) end},
	             {ws_loop, fun(Ws) -> handle_websocket(Ws) end}]).

handle_http(Req) ->
    handle(Req:get(method),Req:resource([lowercase,urlencode]),Req).

handle('GET',["app","popper"],Req) ->
	Req:ok([]);

handle('POST',["apps","popper","channels",ChannelName,"events"],Req) ->
	[{"name",EventName}] = Req:parse_qs(),
    ChannelNameBin = list_to_binary(ChannelName),
    EventNameBin = list_to_binary(EventName),
	{struct,EventData} = mochijson2:decode(Req:get(body)),
	[{_,ChanPid}] = channel_hub:chan_pid_by_name(ChannelNameBin),
	channel:event(ChanPid, EventNameBin, ChannelNameBin, EventData),
	Req:ok([]);

handle('GET',["favicon.ico"],Req) ->
    Path=["favicon.ico"],
    Req:respond(404,[{"Content-Type","text/html"}],["File favicon /",Path,"not found"]);

handle(_Type,_Path,Req) ->
	Req:ok([]).

connection_established(Ws) ->
	receive
		{browser, Msg} ->
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
		    				Ws:send(Response),
							link(ChanPid);
						<<"pusher:unsubscribe">> ->
							[{<<"channel">>,ChannelName}] = Data,
							[{_,ChanPid}] = channel_hub:chan_pid_by_name(ChannelName),
							channel:unsubscribe(ChanPid),
							unlink(ChanPid)
	    			end,
					connection_established(Ws);
				%%Channel Events
				{struct,[{<<"event">>,EventName},{<<"data">>,{struct,EventData}},{<<"channel">>,ChannelName}]} ->
					[{_,ChanPid}] = channel_hub:chan_pid_by_name(ChannelName),
					channel:event(ChanPid,EventName,ChannelName,EventData),
					connection_established(Ws);
				_Ignore ->
					io:format("Incorrect Json:~p ~n",[_Ignore]),
					connection_established(Ws)
			end;
		{event,Json} ->
			Ws:send(Json),
			connection_established(Ws);
		_Ignore ->
			connection_established(Ws)
    end.    

handle_websocket(Ws) ->
    ConnEstablished = util:pusher_connection_json(<< "pusher:connection_established" >>,[{<< "socket_id" >>, 13}]),
    Ws:send(ConnEstablished),
	connection_established(Ws).
    
stop() ->
    misultin:stop().
