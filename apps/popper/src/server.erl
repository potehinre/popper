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

pusher_connection_json(EventName,Data) ->
    mochijson2:encode({struct,[{<< "event" >>, EventName}, {<< "data" >>, {struct,Data}}]}).

pusher_channel_json(EventName,ChannelName,Data) ->
	mochijson2:encode({struct,[{<< "event" >>, EventName}, {<<"channel">>, ChannelName}, {<< "data" >> ,{struct, Data}}]}).

subscribed(Ws,ChanPid) ->
	receive
		{browser, Data} ->
			Decoded = mochijson2:decode(Data),
			{ok,{obj,RecData},_}=Decoded,
			case RecData of
				[{"cmd",<<"leave">>}] ->
					Ws:send("Leaving"),
					channel:unregister_user(ChanPid, self()),
					connection_established(Ws);
				_ ->
					subscribed(Ws,ChanPid)
			end;
		{msg,_From,MsgData} ->
			Json = mochijson2:encode({obj,[{<<"type">>,<<"msg">>},{<<"from">>,_From},{<<"data">>,MsgData}]}),
			Ws:send(Json),
			subscribed(Ws,ChanPid);
		{newuserlist,UserNames} ->
			Json = mochijson2:encode({obj,[{<<"type">>, <<"users">>},{<<"names">>, UserNames}]}),
			Ws:send(Json),
			subscribed(Ws,ChanPid);
		_Ignore -> 
			subscribed(Ws,ChanPid)
 	end.

connection_established(Ws) ->
	receive
		{browser, Msg} ->
	    	{struct,[{<< "event" >>, Event},{<< "data" >>,{struct,_Data}}]} = mochijson2:decode(Msg),
	    	case Event of
				<<"pusher:subscribe">> ->
					[{<< "channel" >>,ChannelName}, _, {<< "channel_data" >>,ChannelData}] = _Data,
					ChanPid = channel_hub:join(ChannelName),
					io:format("Chandata is ~p ~n",[ChannelData]),
					{struct,[{<<"user_id">>,UserId}, {<<"user_info">>,UserInfo}]} = ChannelData,
					channel:register_user(ChanPid, self(), UserId, UserInfo),
		    		RespData = [{<< "presence" >>,{struct,[{<<"ids">>,[1,2,3,4]},{<<"hash">>,<<"users">>},{<<"count">>,3}]}}],
		    		Response = pusher_channel_json(<< "pusher_internal:subscription_succeeded" >>, ChannelName, RespData),
		    		Ws:send(Response)
	    	end,
			connection_established(Ws);
		_Ignore ->
			connection_established(Ws)
    end.    

handle_websocket(Ws) ->
    ConnEstablished = pusher_connection_json(<< "pusher:connection_established" >>,[{<< "socket_id" >>, 13}]),
    Ws:send(ConnEstablished),
	connection_established(Ws).
    
stop() ->
    misultin:stop().

