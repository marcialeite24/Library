-module(library).
-import(lists, [foreach/2]).
-compile(export_all).

-include_lib("stdlib/include/qlc.hrl").

-record(people, {cc, name, address, phoneNumber}).
-record(books, {code, bookName, authors}).
-record(requisition, {cc,code}).

% Create Database 
db_create() ->
    mnesia:create_schema([node()]),
    mnesia:start(),
    mnesia:create_table(people, [{attributes, record_info(fields, people)}]),
    mnesia:create_table(books, [{attributes, record_info(fields, books)}]),
    mnesia:create_table(requisition, [{type,bag},{attributes, record_info(fields, requisition)}]),
    mnesia:stop(),
    io:format("ok").

% Database Initialization
start() ->
    mnesia:start(),
    mnesia:wait_for_tables([people,books,requisition], 2000).

% ******************************** SHOW TABLES ********************************
show_tables(Table) ->
    do(qlc:q([X || X <- mnesia:table(Table)])).

% ******************************** LOOKUP MESSAGES ********************************

%% Given a citizen card number determines the list of books requested by that person
%% SQL equivalent
%% SELECT books.bookName
%% FROM books, requisition
%% WHERE books.code = requisition.code and requisition.cc = cc
get_books(CC) ->
    Book = do(qlc:q([X#books.bookName || X <- mnesia:table(books),
            Y <- mnesia:table(requisition),
            X#books.code =:= Y#requisition.code,
            Y#requisition.cc =:= CC
        ])),
    case Book =/= [] of
        true -> Book;
        false -> {error, cc_doesnt_exist}
    end.

%% Given the book name determines the list of people who requested that book
%% SQL equivalent
%% SELECT people.name
%% FROM books, requisition, people
%% WHERE books.code = requisition.code and people.cc = requisition.cc and books.bookName = BookName
get_loans(BookName) ->
    Name = do(qlc:q([X#people.name || X <- mnesia:table(people),
            Y <- mnesia:table(requisition),
            X#people.cc =:= Y#requisition.cc,
            Z <- mnesia:table(books),
            Z#books.code =:= Y#requisition.code,
            Z#books.bookName =:= BookName
        ])),
    case Name =:= [] of
        true -> {error, book_doesnt_exist};
        false -> Name
    end.

%% Given the code of a book it determines if the book is requested
%% SQL equivalent for the aux_requisitions function
%% SELECT requisition.code
%% FROM requisition, books
%% WHERE books.code = requisition.code and books.code = Code
get_requisitions(Code) ->    
    Bool = length(do(qlc:q([X || X <- mnesia:table(requisition),
            Y <- mnesia:table(books),
            Y#books.code =:= X#requisition.code,
            Y#books.code =:= Code
        ]))),
    case Bool > 0 of
        true -> true;
        false -> false
    end.

%% Given the book name it returns the list of book codes with that name
%% SQL equivalent
%% SELECT books.code
%% FROM books
%% WHERE books.bookName = BookName
get_codes(BookName) ->
    Code = do(qlc:q([X#books.code || X <- mnesia:table(books),
            X#books.bookName =:= BookName
        ])),
    case Code =:= [] of
        true -> {error, book_doesnt_exist};
        false -> Code
    end.

%% Given a citizen card number it returns the number of books requested by that person
%% SQL equivalent for the numRequisitions function
%% SELECT requisition.code
%% FROM requisition, people
%% WHERE requisition.cc = people.cc and people.cc = CC
get_numRequisitions(CC) ->
    length(do(qlc:q([X#requisition.code || X <- mnesia:table(requisition),
            Y <- mnesia:table(people),
            X#requisition.cc =:= Y#people.cc,
            Y#people.cc =:= CC
    ]))).

% ******************************** UPDATE MESSAGES ********************************

%% Given the data of a person and the code of a book adds the pair {person,book} 
%% to the database
add_requisition(CC, Code) ->
    Add_row = #requisition{cc=CC, code=Code},
    F = fun() ->   
        case mnesia:read({people, CC}) =:= [] orelse
            mnesia:read({books, Code}) =:= [] of             
            true -> % Print this if CC or Code doesn't exist in the database
                {error, unknown_values}; 
            false ->  
                case get_requisitions(Code) of
                    true -> {error, repeated_code};    
                    false -> mnesia:write(Add_row)
                end
        end
	end,
    mnesia:transaction(F).

%% Given a citizen card number and the code of a book removes the respective pair 
%% from the database
aux_remove(CC,Code) ->
    do(qlc:q([X#requisition.code || X <- mnesia:table(requisition),
            X#requisition.cc =:= CC,
            X#requisition.code =:= Code
        ])).

remove_requisition(CC,Code) ->
    Remove_row = #requisition{cc=CC, code=Code},
    F = fun() ->
        case aux_remove(CC,Code) =:= [] of
            true -> % Print this if CC or Code doesn't exist in the table requisition
                {error, unknown_values};
            false ->  
                mnesia:delete_object(Remove_row)
        end
	end,
    mnesia:transaction(F).

% ******************************* ADD/REMOVE PEOPLE *******************************
add_people(CC,Name,Address,Phone) ->
    Add_people = #people{cc=CC, name=Name, address=Address, phoneNumber=Phone},
    F = fun() ->   
        case mnesia:read({people, CC}) =/= [] of             
            true -> 
                {error, cc_repeated}; 
            false ->  
                mnesia:write(Add_people)
        end
	end,
    mnesia:transaction(F).

remove_people(CC) ->
    Remove_R = {requisition, CC},
    Remove_P = {people, CC},
    F = fun() ->
        case mnesia:read({requisition,CC}) =/= [] of
            true ->
                mnesia:delete(Remove_R),
                mnesia:delete(Remove_P);        
            false ->
                case mnesia:read({people,CC}) =:= [] of
                    true -> {error, doesnt_exist};
                    false -> mnesia:delete(Remove_P)
                end
        end
    end,
    mnesia:transaction(F).

% ******************************** ADD/REMOVE BOOK ********************************
add_book(Code,BookName,Authors) ->
    Add_book = #books{code=Code, bookName=BookName, authors=Authors},
    F = fun() ->   
        case mnesia:read({books, Code}) =/= [] of             
            true -> 
                {error, code_repeated}; 
            false ->  
                mnesia:write(Add_book)
        end
	end,
    mnesia:transaction(F).

% Auxiliary function to give the CC corresponding to the book requested with this Code
aux(Code) -> 
    do(qlc:q([X#requisition.cc || X <- mnesia:table(requisition),
            X#requisition.code =:= Code
        ])).
% To extract the CC from the list
sum([X|Y]) -> X + sum(Y);
sum([]) -> 0.

remove_book(Code) ->
    % Remove_Req = {requisition, Code},
    Remove_B = {books,Code},    
    F = fun() ->
        X = aux(Code), CC = sum(X),
        case aux(Code) =/= [] of
            true -> 
                mnesia:delete({requisition, CC}),
                mnesia:delete(Remove_B);                       
            false -> 
                case mnesia:read({books,Code}) =:= [] of
                    true -> {error, doesnt_exist};
                    false -> mnesia:delete(Remove_B)
                end
        end
    end,
    mnesia:transaction(F).

% *********************************************************************************
do(Q) ->
    F = fun() -> qlc:e(Q) end,
    {atomic, Val} = mnesia:transaction(F),
    Val.


% Example Tables
example_tables() ->
    [   %% The people table
        {people, 14725836, "Ana", "Porto", 919191123},
        {people, 14893282, "Diogo", "Porto", 939591177},
        {people, 18047254, "Marisa", "Viseu", 923154744},
        {people, 17894562, "Maria", "Lisboa", 911548793},
        {people, 15978624, "Pedro", "Lisboa", 919191123},
        {people, 17845675, "Beatriz", "Coimbra", 935197925},
        {people, 14845736, "Nuno", "Guarda", 963235784},
        %% The books table
        {books, 127, "Erlang", "Aaron"},
        {books, 128, "Erlang", "Miller"},
        {books, 294, "Java", "Smith"},
        {books, 332, "Haskell", "Williams"},
        {books, 432, "Php", "Phillips"},
        {books, 548, "Ruby", "Tindall"},
        {books, 675, "Perl", "Williams"},
        %% The requisition table
        {requisition, 14725836, 294},
        {requisition, 14725836, 127},
        {requisition, 14893282, 128},
        {requisition, 18047254, 432},
        {requisition, 17894562, 548},
        {requisition, 15978624, 675}
    ].

% Reset Tables
reset_tables() ->
    mnesia:clear_table(people),
    mnesia:clear_table(books),
    mnesia:clear_table(requisition),
    F = fun() ->
		foreach(fun mnesia:write/1, example_tables())
	end,
    mnesia:transaction(F).