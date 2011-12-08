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

connection_established(Ws) ->
	receive
		{browser, Msg} ->
	    	{struct,[{<< "event" >>, Event},{<< "data" >>,{struct,Data}}]} = mochijson2:decode(Msg),
	    	case Event of
				<<"pusher:subscribe">> ->
					[{<< "channel" >>,ChannelName}, _, {<< "channel_data" >>,ChannelData}] = Data,
					ChanPid = channel_hub:subscribe(ChannelName),
					io:format("Chandata is ~p ~n",[ChannelData]),
					{struct,[{<<"user_id">>,UserId}, {<<"user_info">>,UserInfo}]} = ChannelData,
					channel:register_user(ChanPid, self(), UserId, UserInfo),
		    		RespData = [{<< "presence" >>,{struct,[{<<"ids">>,[1,2,3,4]},{<<"hash">>,<<"users">>},{<<"count">>,3}]}}],
		    		Response = util:pusher_channel_json(<< "pusher_internal:subscription_succeeded" >>, ChannelName, RespData),
		    		Ws:send(Response);
				<<"pusher:unsubscribe">> ->
					[{<<"channel">>,ChannelName}] = Data,
					channel_hub:unsubscribe(self(),ChannelName),
					Ws:send("Unsubscription succeded")
	    	end,
			connection_established(Ws);
		{member_added,{UserId,UserInfo,ChannelName}} ->
			UserData = [{<<"user_id">>,UserId},{<<"user_info">>,UserInfo}],
			io:format("member added ~p ~p ~n",[UserData,ChannelName]),
			Result = util:pusher_channel_json(<<"pusher_internal:member_added">>, ChannelName, UserData),
			Ws:send(Result),
			connection_established(Ws);
		{member_removed,{UserId,ChannelName}} ->
			UserData = [{<<"user_id">>,UserId}],
			Result = util:pusher_channel_json(<<"pusher_internal:member_removed">>,ChannelName,UserData),
			Ws:send(Result),
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
