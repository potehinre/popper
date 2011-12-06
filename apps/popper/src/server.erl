-module(server).
-export([start_link/1,stop/0]).


start_link(Port) ->
	    misultin:start_link([{port,Port},
							 {loop, fun(Req)   -> handle_http(Req) end},
	                         {ws_loop, fun(Ws) -> handle_websocket(Ws) end}]).


handle_http(Req) ->
    handle(Req:get(method),Req:resource([lowercase,urlencode]),Req).

handle('GET',["app","popper"],Req) ->
	Req:ok([]);

handle('GET',["favicon.ico"],Req) ->
    Path=["favicon.ico"],
    Req:respond(404,[{"Content-Type","text/html"}],["File favicon /",Path,"not found"]).

to_pusher_format(EventName,Data) ->
    mochijson2:encode({struct,[{<< "event" >>, EventName}, {<< "data" >>, {struct,Data}}]}).


websocket_connection_established(Ws) ->
	receive
		{browser, Msg} ->
	    	{struct,[{<< "event" >>, Event},{<< "data" >>,{struct,_Data}}]} = mochijson2:decode(Msg),
	    	case Event of
				<<"pusher:subscribe">> ->
		    		RespData = [{<< "presence" >>,{struct,[{<<"hash">>,<<"users">>},{<<"count">>,3}]}}],
		    		Response = to_pusher_format(<< "pusher_internal:subscription_succeded" >>, RespData),
		    		Ws:send(Response)
	    	end,
			websocket_connection_established(Ws);
		_Ignore ->
			websocket_connection_established(Ws)
    end.    

handle_websocket(Ws) ->
    ConnEstablished = to_pusher_format(<< "pusher:connection_established" >>,[{<< "socket_id" >>,13}]),
    Ws:send(ConnEstablished),
	websocket_connection_established(Ws).
    
stop() ->
    misultin:stop().

