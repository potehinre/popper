-module(popper_app).

-behaviour(application).

%% Application callbacks
-export([start/2, stop/1]).

%% ===================================================================
%% Application callbacks
%% ===================================================================

start(_StartType, _StartArgs) ->
    popper_sup:start_link(),
    application:start(cowboy),
    Dispatch = [{'_',[{[<< "app" >> , << "popper" >>], my_handler, []}]}],
    cowboy:start_listener(http, 400,
			  cowboy_tcp_transport,[{port, 8080}],
			  cowboy_http_protocol,[{dispatch,Dispatch}]).

stop(_State) ->
    ok.
