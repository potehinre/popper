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
			case mochijson2:decode(Msg) of
				%%Connection Events
	    		{struct,[{<< "event" >>, Event},{<< "data" >>,{struct,Data}}]} ->
	    			case Event of
						<<"pusher:subscribe">> ->
							[{<< "channel" >>,ChannelName}, _, {<< "channel_data" >>,ChannelData}] = Data,
							ChanPid = channel_hub:subscribe(ChannelName),
							{struct,[{<<"user_id">>,UserId}, {<<"user_info">>,UserInfo}]} = ChannelData,
							Users =channel:register_user(ChanPid, self(), UserId, UserInfo),
							io:format("Users is ~p ~n",[Users]),
							Ids = lists:map(fun(X) -> element(1,X) end,Users),
							Count = length(Users),
		    				RespData = [{<< "presence" >>,{struct,[{<<"ids">>,Ids},{<<"hash">>,Users},{<<"count">>,Count}]}}],
		    				Response = util:pusher_channel_json(<< "pusher_internal:subscription_succeeded" >>, ChannelName, RespData),
		    				Ws:send(Response),
							link(ChanPid);
						<<"pusher:unsubscribe">> ->
							[{<<"channel">>,ChannelName}] = Data,
							channel_hub:unsubscribe(self(),ChannelName),
							ChanPid = channel_hub:chan_pid_by_name(ChannelName),
							unlink(ChanPid),
							Ws:send("Unsubscription succeded")
	    			end,
					connection_established(Ws);
				%%Channel Events
				{struct,[{<<"event">>,EventName},{<<"data">>,{struct,EventData}},{<<"channel">>,ChannelName}]} ->
					[{_,ChanPid}] = channel_hub:chan_pid_by_name(ChannelName),
					channel:broadcast_event(ChanPid,EventName,ChannelName,EventData),
					connection_established(Ws)
			end;			
		{member_added,{UserId,UserInfo,ChannelName}} ->
			UserData = [{<<"user_id">>,UserId},{<<"user_info">>,UserInfo}],
			Result = util:pusher_channel_json(<<"pusher_internal:member_added">>, ChannelName, UserData),
			Ws:send(Result),
			connection_established(Ws);
		{member_removed,{UserId,ChannelName}} ->
			UserData = [{<<"user_id">>,UserId}],
			Result = util:pusher_channel_json(<<"pusher_internal:member_removed">>,ChannelName,UserData),
			Ws:send(Result),
			connection_established(Ws);
		{custom_event,{EventName,ChannelName,EventData}} ->
			io:format("Custom event received! ~p ~p ~p ~n",[EventName,ChannelName,EventData]),
			Result = util:pusher_channel_json(EventName, ChannelName, EventData),
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
