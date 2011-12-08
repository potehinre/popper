-module(util).
-export([pusher_connection_json/2,pusher_channel_json/3]).

pusher_connection_json(EventName,Data) ->
    mochijson2:encode({struct,[{<< "event" >>, EventName}, {<< "data" >>, {struct,Data}}]}).

pusher_channel_json(EventName,ChannelName,Data) ->
	mochijson2:encode({struct,[{<< "event" >>, EventName}, {<<"channel">>, ChannelName}, {<< "data" >> ,{struct, Data}}]}).