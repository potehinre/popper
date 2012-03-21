-module(popper_app).

-behaviour(application).

%% Application callbacks
-export([start/2, stop/1]).

%% ===================================================================
%% Application callbacks
%% ===================================================================

start(_StartType, _StartArgs) ->
    application:start(cowboy),
    Dispatch = [{'_', [{'_', my_handler, []}]}],
    cowboy:start_listener(ws_server, 100,
  			  cowboy_tcp_transport, [{port,1234}],
  			  cowboy_http_protocol, [{dispatch, Dispatch}]),
    popper_sup:start_link().

stop(_State) ->
    ok.
