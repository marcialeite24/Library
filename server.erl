-module(server).
-compile(export_all).

% Start Connection
go() -> register(pid, spawn(fun() -> loop() end)).
% Create Database
db_create() -> rpc({db_create}). 
% Database Initialization
start() -> rpc({start}).
% Reset Tables
reset_tables() -> rpc({reset_tables}).
% Example Tables
example_tables() -> rpc({example_tables}).
% SHOW TABLES
show_tables(Table) -> rpc({show_tables,Table}).
% LOOKUP MESSAGES
get_books(CC) -> rpc({get_books,CC}).
get_loans(BookName) -> rpc({get_loans,BookName}).
get_requisitions(Code) -> rpc({get_requisitions,Code}).
get_codes(BookName) -> rpc({get_codes,BookName}).
get_numRequisitions(CC) -> rpc({get_numRequisitions,CC}).
% UPDATE MESSAGES
add_requisition(CC,Code) -> rpc({add_requisition,CC,Code}).
remove_requisition(CC,Code) -> rpc({remove_requisition,CC,Code}).
% ADD/REMOVE PEOPLE
add_people(CC,Name,Address,Phone) -> rpc({add_people,CC,Name,Address,Phone}).
remove_people(CC) -> rpc({remove_people,CC}).
% ADD/REMOVE BOOK
add_book(Code,BookName,Authors) -> rpc({add_book,Code,BookName,Authors}).
remove_book(Code) -> rpc({remove_book,Code}).

rpc(Q) ->
	Ref = make_ref(),
    pid ! {self(), Ref, Q},
    receive
	{pid, Ref, Reply} ->
	    Reply
    end.

loop() ->  
    receive
	% Create Database
	{From, Ref, {db_create}} -> 
	    From ! {pid, Ref, library:db_create()},
	    loop();
	% Database Initialization
	{From, Ref, {start}} -> 
	    From ! {pid, Ref, library:start()},
	    loop();
	% Reset Tables
	{From, Ref, {reset_tables}} -> 
	    From ! {pid, Ref, library:reset_tables()},
	    loop();
	% Example Tables
	{From, Ref, {example_tables}} -> 
	    From ! {pid, Ref, library:example_tables()},
	    loop();
	% SHOW TABLES
	{From, Ref, {show_tables,Table}} -> 
	    From ! {pid, Ref, library:show_tables(Table)},
	    loop();
	% LOOKUP MESSAGES
	{From, Ref, {get_books,CC}} -> 
	    From ! {pid, Ref, library:get_books(CC)},
	    loop();
	{From, Ref, {get_loans,BookName}} -> 
	    From ! {pid, Ref, library:get_loans(BookName)},
	    loop();
	{From, Ref, {get_requisitions,Code}} -> 
	    From ! {pid, Ref, library:get_requisitions(Code)},
	    loop();
	{From, Ref, {get_codes,BookName}} -> 
	    From ! {pid, Ref, library:get_codes(BookName)},
	    loop();
	{From, Ref, {get_numRequisitions,CC}} -> 
	    From ! {pid, Ref, library:get_numRequisitions(CC)},
	    loop();
	% UPDATE MESSAGES
	{From, Ref, {add_requisition,CC,Code}} -> 
	    From ! {pid, Ref, library:add_requisition(CC,Code)},
	    loop();
	{From, Ref, {remove_requisition,CC,Code}} -> 
	    From ! {pid, Ref, library:remove_requisition(CC,Code)},
	    loop();
	% ADD/REMOVE PEOPLE
	{From, Ref, {add_people,CC,Name,Address,Phone}} -> 
	    From ! {pid, Ref, library:add_people(CC,Name,Address,Phone)},
	    loop();
	{From, Ref, {remove_people,CC}} -> 
	    From ! {pid, Ref, library:remove_people(CC)},
	    loop();
	% ADD/REMOVE BOOK
	{From, Ref, {add_book,CC,BookName,Authors}} -> 
	    From ! {pid, Ref, library:add_book(CC,BookName,Authors)},
	    loop();
	{From, Ref, {remove_book,Code}} -> 
	    From ! {pid, Ref, library:remove_book(Code)},
	    loop()
    end.