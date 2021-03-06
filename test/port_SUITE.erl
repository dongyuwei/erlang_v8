-module(port_SUITE).

-include_lib("common_test/include/ct.hrl").

-export([all/0]).
-export([init_per_suite/1]).
-export([end_per_suite/1]).

-export([eval/1]).
-export([call/1]).
-export([return_type/1]).
-export([nested_return_type/1]).
-export([errors/1]).
-export([timeout/1]).
-export([reset/1]).
-export([restart/1]).
-export([single_source/1]).
-export([multi_source/1]).
-export([file_source/1]).
-export([multiple_eval_with_reset/1]).
-export([multiple_vms/1]).
-export([big_input/1]).
-export([escaped_control_characters/1]).

%% Callbacks

all() ->
    [
        eval,
        call,
        return_type,
        nested_return_type,
        errors,
        timeout,
        reset,
        restart,
        single_source,
        multi_source,
        file_source,
        multiple_eval_with_reset,
        multiple_vms,
        big_input,
        escaped_control_characters
    ].

init_per_suite(Config) ->
    application:start(jsx),
    application:start(erlang_v8),
    Config.

end_per_suite(_Config) ->
    ok.

%% Tests

eval(_Config) ->
    {ok, P} = erlang_v8:start_vm(),

    {ok, 2} = erlang_v8:eval(P, <<"1 + 1">>),
    {ok, 5} = erlang_v8:eval(P, <<"var a = 3; a + 2;">>),

    erlang_v8:stop_vm(P),
    ok.

call(_Config) ->
    {ok, P} = erlang_v8:start_vm(),

    %% sum fun
    {ok, undefined} =
        erlang_v8:eval(P, <<"function sum(a, b) { return a + b }">>),
    {ok, 3} = erlang_v8:call(P, <<"sum">>, [1, 2]),
    {ok, 4} = erlang_v8:call(P, <<"sum">>, [2, 2]),
    {ok, <<"helloworld">>} =
        erlang_v8:call(P, <<"sum">>, [<<"hello">>, <<"world">>]),
        
    %% a few arguments
    {ok, undefined} =
        erlang_v8:eval(P, <<"function mul(a, b, c, d) { return a * b * c * d }">>),
    {ok, 1} = erlang_v8:call(P, <<"mul">>, [1, 1, 1, 1]),

    %% object arguments
    {ok, undefined} =
        erlang_v8:eval(P, <<"function get(o) { return o.a; }">>),
    {ok, undefined} = erlang_v8:call(P, <<"get">>, [2, 2]),
    {ok, 1} = erlang_v8:call(P, <<"get">>, [[{a, 1}]]),
    
    %% object fun
    %% {ok, undefined} =
    %%     erlang_v8:eval(P, <<"var x = { y: function z() { return 1; } }">>),
    %% {ok, 1} = erlang_v8:call(P, <<"x.y">>, []),

    erlang_v8:stop_vm(P),
    ok.

return_type(_Config) ->
    {ok, P} = erlang_v8:start_vm(),

    {ok, 1} = erlang_v8:eval(P, <<"1">>),
    {ok, [{<<"a">>, 1}]} = erlang_v8:eval(P, <<"var x = { a: 1 }; x">>),
    {ok, [1]} = erlang_v8:eval(P, <<"[1]">>),
    {ok, true} = erlang_v8:eval(P, <<"true">>),
    {ok, null} = erlang_v8:eval(P, <<"null">>),
    {ok, 1.1} = erlang_v8:eval(P, <<"1.1">>),

    erlang_v8:stop_vm(P),
    ok.

nested_return_type(_Config) ->
    {ok, P} = erlang_v8:start_vm(),

    {ok, [
           {<<"val">>, 1},
           {<<"list">>, [1, 2, 3]},
           {<<"obj">>, [{<<"val">>, 1}]}
    ]} = erlang_v8:eval(P, <<"
    var x = {
        val: 1,
        list: [1, 2, 3],
        obj: {
            val: 1
        }
    };
    x
    ">>),

    erlang_v8:stop_vm(P),
    ok.
 
errors(_Config) ->
    {ok, P} = erlang_v8:start_vm(),

    {error, <<"exception">>} = erlang_v8:eval(P, <<"throw 'exception';">>),

    {error, <<"ReferenceError: i_do_not_exist is not defined", _/binary>>} =
        erlang_v8:call(P, <<"i_do_not_exist">>, []),

    erlang_v8:stop_vm(P),
    ok.

timeout(_Config) ->
    {ok, P} = erlang_v8:start_vm(),

    {error, timeout} = erlang_v8:eval(P, <<"while (true) {}">>, 1),

    erlang_v8:stop_vm(P),
    ok.

reset(_Config) ->
    {ok, P} = erlang_v8:start_vm([{source, <<"var erlang_v8 = 'yes';">>}]),

    {ok, <<"yes">>} = erlang_v8:eval(P, <<"erlang_v8">>),
    erlang_v8:reset_vm(P),
    {ok, <<"yes">>} = erlang_v8:eval(P, <<"erlang_v8">>),

    {ok, <<"no">>} = erlang_v8:eval(P, <<"erlang_v8 = 'no';">>),
    erlang_v8:reset_vm(P),
    {ok, <<"yes">>} = erlang_v8:eval(P, <<"erlang_v8">>),

    {ok, <<"test">>} = erlang_v8:eval(P, <<"String.imposter = 'test';">>),
    erlang_v8:reset_vm(P),
    {ok, undefined} = erlang_v8:eval(P, <<"String.imposter">>),

    {ok, undefined} =
        erlang_v8:eval(P, <<"function sum(a, b) { return a + b }">>),
    {ok, 2} = erlang_v8:call(P, <<"sum">>, [1, 1]),

    erlang_v8:reset_vm(P),

    {error, <<"ReferenceError: sum is not defined", _/binary>>} =
        erlang_v8:call(P, <<"sum">>, [1, 1]),

    erlang_v8:stop_vm(P),
    ok.

restart(_Config) ->
    {ok, P} = erlang_v8:start_vm([{source, <<"var erlang_v8 = 'yes';">>}]),

    {ok, <<"yes">>} = erlang_v8:eval(P, <<"erlang_v8">>),
    erlang_v8:restart_vm(P),
    {ok, <<"yes">>} = erlang_v8:eval(P, <<"erlang_v8">>),

    {ok, <<"no">>} = erlang_v8:eval(P, <<"erlang_v8 = 'no';">>),
    erlang_v8:restart_vm(P),
    {ok, <<"yes">>} = erlang_v8:eval(P, <<"erlang_v8">>),

    {ok, <<"test">>} = erlang_v8:eval(P, <<"String.imposter = 'test';">>),
    erlang_v8:restart_vm(P),
    {ok, undefined} = erlang_v8:eval(P, <<"String.imposter">>),

    {ok, undefined} =
        erlang_v8:eval(P, <<"function sum(a, b) { return a + b }">>),
    {ok, 2} = erlang_v8:call(P, <<"sum">>, [1, 1]),

    erlang_v8:restart_vm(P),

    {error, <<"ReferenceError: sum is not defined", _/binary>>} =
        erlang_v8:call(P, <<"sum">>, [1, 1]),

    erlang_v8:stop_vm(P),
    ok.

single_source(_Config) ->
    {ok, P} = erlang_v8:start_vm([{source, <<"var erlang_v8 = 'yes';">>}]),
    {ok, <<"yes">>} = erlang_v8:eval(P, <<"erlang_v8">>),
    erlang_v8:reset_vm(P),
    {ok, <<"yes">>} = erlang_v8:eval(P, <<"erlang_v8">>),
    {ok, 3} = erlang_v8:eval(P, <<"lol = 3;">>),
    {ok, 3} = erlang_v8:eval(P, <<"lol">>),
    erlang_v8:reset_vm(P),
    {error, <<"ReferenceError: lol is not defined", _/binary>>} = erlang_v8:eval(P, <<"lol">>),
    erlang_v8:stop_vm(P),
    ok.

multi_source(_Config) ->
    {ok, P} = erlang_v8:start_vm([{source, <<"var x = 1; var y = 2;">>}]),
    {ok, 1} = erlang_v8:eval(P, <<"x;">>),
    {ok, 2} = erlang_v8:eval(P, <<"y;">>),
    erlang_v8:restart_vm(P),
    {ok, 1} = erlang_v8:eval(P, <<"x;">>),
    {ok, 2} = erlang_v8:eval(P, <<"y;">>),
    erlang_v8:stop_vm(P),
    ok.

file_source(_Config) ->
    Directory = filename:dirname(code:which(?MODULE)),
    Path = filename:join(Directory, "js/variables.js"),
    {ok, P} = erlang_v8:start_vm([{file, Path}]),
    {ok, 3} = erlang_v8:eval(P, <<"z;">>),
    erlang_v8:reset_vm(P),
    {ok, 3} = erlang_v8:eval(P, <<"z;">>),
    erlang_v8:stop_vm(P),
    ok.

multiple_eval_with_reset(_Config) ->
    {ok, P} = erlang_v8:start_vm([{source, <<"var erlang_v8 = 'yes';">>}]),
    [begin
         {ok, 2} = erlang_v8:eval(P, <<"1 + 1">>),
         {ok, 2} = erlang_v8:eval(P, <<"1 + 1">>),
         {ok, 2} = erlang_v8:eval(P, <<"1 + 1">>),
         {ok, 2} = erlang_v8:eval(P, <<"1 + 1">>),
         erlang_v8:reset_vm(P)
     end || _ <- lists:seq(0, 1)],
    erlang_v8:stop_vm(P),
    ok.

multiple_vms(_Config) ->
    {ok, VM1} = erlang_v8:start_vm(),
    {ok, VM2} = erlang_v8:start_vm(),
    {ok, undefined} = erlang_v8:eval(VM1, <<"var x = 1;">>),
    {ok, undefined} = erlang_v8:eval(VM2, <<"var x = 2;">>),
    {ok, 1} = erlang_v8:eval(VM1, <<"x;">>),
    {ok, 2} = erlang_v8:eval(VM2, <<"x;">>),
    ok = erlang_v8:stop_vm(VM1),
    ok = erlang_v8:stop_vm(VM2),
    ok.

big_input(_Config) ->
    {ok, VM} = erlang_v8:start_vm([{max_source_size, 1000}]),
    {ok, undefined} = erlang_v8:eval(VM, <<"function call(arg) {
        return arg;
    }">>),

    {error, invalid_source_size} = erlang_v8:call(VM, <<"call">>,
                                                  [random_bytes(1000)]),

    {ok, _} = erlang_v8:call(VM, <<"call">>, [random_bytes(500)]),

    ok = erlang_v8:stop_vm(VM),
    ok.

escaped_control_characters(_Config) ->
    {ok, VM} = erlang_v8:start_vm(),
    {ok, undefined} = erlang_v8:eval(VM, <<"function call(arg) {
        return arg;
    }">>),
    Bytes = <<"\ntestar\nfestar\n">>,
    {ok, <<"\ntestar\nfestar\n">>} = erlang_v8:call(VM, <<"call">>, [Bytes]),
    ok = erlang_v8:stop_vm(VM),
    ok.

%% Helpers

random_bytes(N) ->
    list_to_binary([random:uniform(26) + 96 || _ <- lists:seq(0, N - 1)]).
