
%{
/*
 * Copyright (c) 2001 Stephen Williams (steve@icarus.com)
 *
 *    This source code is free software; you can redistribute it
 *    and/or modify it in source code form under the terms of the GNU
 *    General Public License as published by the Free Software
 *    Foundation; either version 2 of the License, or (at your option)
 *    any later version.
 *
 *    This program is distributed in the hope that it will be useful,
 *    but WITHOUT ANY WARRANTY; without even the implied warranty of
 *    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *    GNU General Public License for more details.
 *
 *    You should have received a copy of the GNU General Public License
 *    along with this program; if not, write to the Free Software
 *    Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA
 */
#if !defined(WINNT)
#ident "$Id: parse.y,v 1.43 2002/01/03 04:19:02 steve Exp $"
#endif

# include  "parse_misc.h"
# include  "compile.h"
# include  "delay.h"
# include  <stdio.h>
# include  <stdlib.h>
# include  <assert.h>

/*
 * These are bits in the lexor.
 */
extern FILE*yyin;

%}

%union {
      char*text;
      char **table;
      long numb;

      comp_operands_t opa;

      struct symb_s  symb;
      struct symbv_s symbv;

      struct numbv_s numbv;

      struct symb_s vect;

      struct argv_s argv;
      vpiHandle vpi;

      vvp_delay_t cdelay;
};


%token K_ARITH_DIV K_ARITH_MOD K_ARITH_MULT K_ARITH_SUB K_ARITH_SUM
%token K_CMP_GE K_CMP_GT
%token K_EVENT K_EVENT_OR K_FUNCTOR K_NET K_NET_S
%token K_RESOLV K_SCOPE K_SHIFTL K_SHIFTR K_THREAD
%token K_UDP K_UDP_C K_UDP_S
%token K_MEM K_MEM_P K_MEM_I
%token K_FORCE 
%token K_VAR K_VAR_S K_vpi_call K_vpi_func K_disable K_fork
%token K_vpi_module K_vpi_time_precision

%token <text> T_INSTR
%token <text> T_LABEL
%token <numb> T_NUMBER
%token <text> T_STRING
%token <text> T_SYMBOL
%token <vect> T_VECTOR

%type <symb>  symbol symbol_opt
%type <symbv> symbols symbols_net
%type <numbv> numbers
%type <text> label_opt
%type <opa>  operand operands operands_opt
%type <table> udp_table

%type <argv> argument_opt argument_list
%type <vpi>  argument
%type <cdelay> delay

%%

source_file : header_lines_opt program ;

header_lines_opt : header_lines | ;

header_lines
	: header_line
	| header_lines header_line
	;

header_line
	: K_vpi_module T_STRING ';'
		{ compile_load_vpi_module($2); }
	| K_vpi_time_precision '+' T_NUMBER ';'
		{ compile_vpi_time_precision($3); }
	| K_vpi_time_precision '-' T_NUMBER ';'
		{ compile_vpi_time_precision(-$3); }
	;

  /* A program is simply a list of statements. No other structure. */
program
	: statement
	| program statement
	;


  /* A statement can be any of the following. In all cases, the
     statment is terminated by a semi-colon. In general, a statement
     has a label, an opcode of some source, and operands. The
     structure of the operands depends on the opcode. */

statement

  /* Functor statements define functors. The functor must have a
     label and a type name, and may have operands. The functor may
     also have a delay specification and output strengths. */

	: T_LABEL K_FUNCTOR T_SYMBOL delay ',' symbols ';'
		{ compile_functor($1, $3, $4, 6, 6, $6.cnt, $6.vect); }

	| T_LABEL K_FUNCTOR T_SYMBOL delay
	          '[' T_NUMBER T_NUMBER ']' ',' symbols ';'
		{ unsigned str0 = $6;
		  unsigned str1 = $7;
		  compile_functor($1, $3, $4, str0, str1, $10.cnt, $10.vect);
		}


  /* UDP statements define or instantiate UDPs.  Definitions take a 
     label (UDP type id) a name (string), the number of inputs, and 
     for sequentioal UDPs the initial value. */

	| T_LABEL K_UDP_S T_STRING ',' T_NUMBER ',' T_NUMBER ',' udp_table ';'
		{ compile_udp_def(1, $1, $3, $5, $7, $9); }

	| T_LABEL K_UDP_C T_STRING ',' T_NUMBER ',' udp_table ';'
		{ compile_udp_def(0, $1, $3, $5, 0, $7); }

	| T_LABEL K_UDP T_SYMBOL delay ',' symbols ';'
		{ compile_udp_functor($1, $3, $4, $6.cnt, $6.vect); }


  /* Memory.  Definition, port, initialization */

        | T_LABEL K_MEM T_STRING ',' T_NUMBER ',' T_NUMBER ',' numbers ';'
		{ compile_memory($1, $3, $5, $7, $9.cnt, $9.nvec); }

        | T_LABEL K_MEM_P T_SYMBOL ',' T_NUMBER ',' T_NUMBER ',' T_NUMBER ',' symbols ';'
		{ compile_memory_port($1, $3, $5, $7, $9, $11.cnt, $11.vect); }

	| mem_init_stmt


  /* Resolver statements are very much like functors. They are
     compiled to functors of a different mode. */

	| T_LABEL K_RESOLV T_SYMBOL ',' symbols ';'
		{ struct symbv_s obj = $5;
		  compile_resolver($1, $3, obj.cnt, obj.vect);
		}

  /* Force statements are very much like functors. They are
     compiled to functors of a different mode. */

	| T_LABEL K_FORCE symbol ',' symbols ';'
		{ struct symbv_s obj = $5;
		  compile_force($1, $3, obj.cnt, obj.vect);
		}

  /* Arithmetic statements generate functor arrays of a given width
     that take like size input vectors. */

	| T_LABEL K_ARITH_DIV T_NUMBER ',' symbols ';'
		{ struct symbv_s obj = $5;
		  compile_arith_div($1, $3, obj.cnt, obj.vect);
		}

	| T_LABEL K_ARITH_MOD T_NUMBER ',' symbols ';'
		{ struct symbv_s obj = $5;
		  compile_arith_mod($1, $3, obj.cnt, obj.vect);
		}

	| T_LABEL K_ARITH_MULT T_NUMBER ',' symbols ';'
		{ struct symbv_s obj = $5;
		  compile_arith_mult($1, $3, obj.cnt, obj.vect);
		}

	| T_LABEL K_ARITH_SUB T_NUMBER ',' symbols ';'
		{ struct symbv_s obj = $5;
		  compile_arith_sub($1, $3, obj.cnt, obj.vect);
		}

	| T_LABEL K_ARITH_SUM T_NUMBER ',' symbols ';'
		{ struct symbv_s obj = $5;
		  compile_arith_sum($1, $3, obj.cnt, obj.vect);
		}

	| T_LABEL K_CMP_GE T_NUMBER ',' symbols ';'
		{ struct symbv_s obj = $5;
		  compile_cmp_ge($1, $3, obj.cnt, obj.vect);
		}

	| T_LABEL K_CMP_GT T_NUMBER ',' symbols ';'
		{ struct symbv_s obj = $5;
		  compile_cmp_gt($1, $3, obj.cnt, obj.vect);
		}


	| T_LABEL K_SHIFTL T_NUMBER ',' symbols ';'
		{ struct symbv_s obj = $5;
		  compile_shiftl($1, $3, obj.cnt, obj.vect);
		}

	| T_LABEL K_SHIFTR T_NUMBER ',' symbols ';'
		{ struct symbv_s obj = $5;
		  compile_shiftr($1, $3, obj.cnt, obj.vect);
		}


  /* Event statements take a label, a type (the first T_SYMBOL) and a
     list of inputs. If the type is instead a string, then we have a
     named event instead. */

	| T_LABEL K_EVENT T_SYMBOL ',' symbols ';'
		{ compile_event($1, $3, $5.cnt, $5.vect); }

	| T_LABEL K_EVENT T_STRING ';'
		{ compile_event($1, $3, 0, 0); }

	| T_LABEL K_EVENT_OR symbols ';'
		{ compile_event($1, 0, $3.cnt, $3.vect); }


  /* Instructions may have a label, and have zero or more
     operands. The meaning of and restrictions on the operands depends
     on the specific instruction. */

	| label_opt T_INSTR operands_opt ';'
		{ compile_code($1, $2, $3); }

	| T_LABEL ';'
		{ compile_codelabel($1); }

  /* %vpi_call statements are instructions that have unusual operand
     requirements so are handled by their own rules. The %vpi_func
     statement is a variant of %vpi_call that includes a thread vector
     after the name, and is used for function calls. */

	| label_opt K_vpi_call T_STRING argument_opt ';'
		{ compile_vpi_call($1, $3, $4.argc, $4.argv); }

	| label_opt K_vpi_func T_STRING ',' 
	  T_NUMBER ',' T_NUMBER argument_opt ';'
		{ compile_vpi_func_call($1, $3, $5, $7, $8.argc, $8.argv); }

  /* %disable statements are instructions that takes a scope reference
     as an operand. It therefore is parsed uniquely. */

	| label_opt K_disable symbol ';'
		{ compile_disable($1, $3); }


	| label_opt K_fork symbol ',' symbol ';'
		{ compile_fork($1, $3, $5); }


  /* Scope statements come in two forms. There are the scope
     declaration and the scope recall. */

	| T_LABEL K_SCOPE T_SYMBOL ',' T_STRING ';'
		{ compile_scope_decl($1, $3, $5, 0); }

	| T_LABEL K_SCOPE T_SYMBOL ',' T_STRING ',' T_SYMBOL ';'
		{ compile_scope_decl($1, $3, $5, $7); }

	|         K_SCOPE T_SYMBOL ';'
		{ compile_scope_recall($2); }

  /* Thread statements declare a thread with its starting address. The
     starting address must already be defined. */

	|         K_THREAD T_SYMBOL ';'
		{ compile_thread($2); }

  /* Var statements declare a bit of a variable. This also implicitly
     creates a functor with the same name that acts as the output of
     the variable in the netlist. */

	| T_LABEL K_VAR T_STRING ',' T_NUMBER ',' T_NUMBER ';'
		{ compile_variable($1, $3, $5, $7, false); }

	| T_LABEL K_VAR_S T_STRING ',' T_NUMBER ',' T_NUMBER ';'
		{ compile_variable($1, $3, $5, $7, true); }

  /* Net statements are similar to .var statements, except that they
     declare nets, and they have an input list. */

	| T_LABEL K_NET T_STRING ',' T_NUMBER ',' T_NUMBER ',' symbols_net ';'
		{ compile_net($1, $3, $5, $7, false, $9.cnt, $9.vect); }

	| T_LABEL K_NET_S T_STRING ',' T_NUMBER ',' T_NUMBER ',' symbols_net ';'
		{ compile_net($1, $3, $5, $7, true, $9.cnt, $9.vect); }

  /* Oh and by the way, empty statements are OK as well. */

	| ';'
	;


  /* There are a few places where the label is optional. This rule
     returns the label value if present, or 0 if not. */

label_opt
	: T_LABEL { $$ = $1; }
	|         { $$ = 0; }
	;

operands_opt
	: operands { $$ = $1; }
	|          { $$ = 0; }
	;

operands
	: operands ',' operand
		{ comp_operands_t opa = $1;
		  assert(opa->argc < 3);
		  assert($3->argc == 1);
		  opa->argv[opa->argc] = $3->argv[0];
		  opa->argc += 1;
		  free($3);
		  $$ =  opa;
		}
	| operand
		{ $$ = $1; }
	;

operand
	: symbol
		{ comp_operands_t opa = (comp_operands_t)
			calloc(1, sizeof(struct comp_operands_s));
		  opa->argc = 1;
		  opa->argv[0].ltype = L_SYMB;
		  opa->argv[0].symb = $1;
		  $$ = opa;
		}
	| T_NUMBER
		{ comp_operands_t opa = (comp_operands_t)
			calloc(1, sizeof(struct comp_operands_s));
		  opa->argc = 1;
		  opa->argv[0].ltype = L_NUMB;
		  opa->argv[0].numb = $1;
		  $$ = opa;
		}
	;


  /* The argument_list is a list of vpiHandle objects that can be
     passed to a %vpi_call statement (and hence built into a
     vpiCallSysTask handle). We build up an arbitrary sized list with
     the struct argv_s type.

     Each argument of the call is represented as a vpiHandle
     object.  If the argument is a symbol, the symbol name will be 
     kept, until the argument_list is complete.  Then, all symbol
     lookups will be attemted.  Postoned lookups will point into the 
     resulting $$->argv.
     If it is some other supported object, the necessary
     vpiHandle object is created to support it. */

argument_opt
	: ',' argument_list
		{ 
		  argv_sym_lookup(&$2);
		  $$ = $2;
		}
	| /* empty */
		{ struct argv_s tmp;
		  argv_init(&tmp);
		  $$ = tmp;
		}
	;

argument_list
	: argument
		{ struct argv_s tmp;
		  argv_init(&tmp);
		  argv_add(&tmp, $1);
		  $$ = tmp;
		}
	| argument_list ',' argument
		{ struct argv_s tmp = $1;
		  argv_add(&tmp, $3);
		  $$ = tmp;
		}
	| T_SYMBOL
		{ struct argv_s tmp;
		  argv_init(&tmp);
		  argv_sym_add(&tmp, $1);
		  $$ = tmp;
		}
	| argument_list ',' T_SYMBOL
		{ struct argv_s tmp = $1;
		  argv_sym_add(&tmp, $3);
		  $$ = tmp;
		}
	;

argument
	: T_STRING
		{ $$ = vpip_make_string_const($1); }
	| T_VECTOR
		{ $$ = vpip_make_binary_const($1.idx, $1.text); }
	;


  /* functor operands can only be a list of symbols. */
symbols
	: symbol
		{ struct symbv_s obj;
		  symbv_init(&obj);
		  symbv_add(&obj, $1);
		  $$ = obj;
		}
	| symbols ',' symbol
		{ struct symbv_s obj = $1;
		  symbv_add(&obj, $3);
		  $$ = obj;
		}
	;


numbers
	: T_NUMBER
		{ struct numbv_s obj;
		  numbv_init(&obj);
		  numbv_add(&obj, $1);
		  $$ = obj;
		}
	| numbers ',' T_NUMBER
		{ struct numbv_s obj = $1;
		  numbv_add(&obj, $3);
		  $$ = obj;
		}
	;


symbols_net
	: symbol_opt
		{ struct symbv_s obj;
		  symbv_init(&obj);
		  symbv_add(&obj, $1);
		  $$ = obj;
		}
	| symbols_net ',' symbol_opt
		{ struct symbv_s obj = $1;
		  symbv_add(&obj, $3);
		  $$ = obj;
		}
	;

  /* In some cases, simple pointer arithmetic is allowed. In
     particular, functor vectors can be indexed with the [] syntax,
     with values from 0 up. */

symbol
	: T_SYMBOL
		{ $$.text = $1;
		  $$.idx = 0;
		}
	| T_SYMBOL '[' T_NUMBER ']'
		{ $$.text = $1;
		  $$.idx = $3;
		}

symbol_opt
	: symbol
		{ $$ = $1; }
	|
		{ $$.text = 0;
		  $$.idx = 0;
		}
	;

udp_table
	: T_STRING
		{ $$ = compile_udp_table(0x0, $1); }
	| udp_table ',' T_STRING
		{ $$ = compile_udp_table($1,  $3); }
	;

mem_init_stmt
	: K_MEM_I symbol ',' T_NUMBER o_komma 
		{ compile_memory_init($2.text, $2.idx, $4); }
        | mem_init_stmt T_NUMBER o_komma 
		{ compile_memory_init(0x0,     0,      $2); }
	;

o_komma
	: /* empty */
	| ','
	;

delay
	: /* empty */ 
		{ $$ = 0; }
	| '(' T_NUMBER ')'
		{ $$ = new vvp_delay_2_s($2, $2); }
	| '(' T_NUMBER ',' T_NUMBER ')'
		{ $$ = new vvp_delay_2_s($2, $4); }
	| '(' T_NUMBER ',' T_NUMBER ',' T_NUMBER ')'
		{ $$ = new vvp_delay_3_s($2, $4, $6); }
	;

%%

int compile_design(const char*path)
{
      yypath = path;
      yyline = 1;
      yyin = fopen(path, "r");
      if (yyin == 0) {
	    fprintf(stderr, "%s: Unable to open input file.\n", path);
	    return -1;
      }

      int rc = yyparse();
      return rc;
}


/*
 * $Log: parse.y,v $
 * Revision 1.43  2002/01/03 04:19:02  steve
 *  Add structural modulus support down to vvp.
 *
 * Revision 1.42  2001/12/14 02:04:49  steve
 *  Support strength syntax on functors.
 *
 * Revision 1.41  2001/12/06 03:31:25  steve
 *  Support functor delays for gates and UDP devices.
 *  (Stephan Boettcher)
 *
 * Revision 1.40  2001/11/01 03:00:19  steve
 *  Add force/cassign/release/deassign support. (Stephan Boettcher)
 *
 * Revision 1.39  2001/10/31 04:27:47  steve
 *  Rewrite the functor type to have fewer functor modes,
 *  and use objects to manage the different types.
 *  (Stephan Boettcher)
 *
 * Revision 1.38  2001/10/16 02:47:37  steve
 *  Add arith/div object.
 *
 * Revision 1.37  2001/10/15 02:58:27  steve
 *  Carry the type of the scope (Stephan Boettcher)
 *
 * Revision 1.36  2001/07/11 04:43:57  steve
 *  support postpone of $systask parameters. (Stephan Boettcher)
 *
 * Revision 1.35  2001/07/07 02:57:33  steve
 *  Add the .shift/r functor.
 *
 * Revision 1.34  2001/07/06 04:46:44  steve
 *  Add structural left shift (.shift/l)
 *
 * Revision 1.33  2001/06/30 23:03:17  steve
 *  support fast programming by only writing the bits
 *  that are listed in the input file.
 *
 * Revision 1.32  2001/06/16 23:45:05  steve
 *  Add support for structural multiply in t-dll.
 *  Add code generators and vvp support for both
 *  structural and behavioral multiply.
 *
 * Revision 1.31  2001/06/15 04:07:58  steve
 *  Add .cmp statements for structural comparison.
 *
 * Revision 1.30  2001/06/15 03:28:31  steve
 *  Change the VPI call process so that loaded .vpi modules
 *  use a function table instead of implicit binding.
 *
 * Revision 1.29  2001/06/07 03:09:03  steve
 *  Implement .arith/sub subtraction.
 *
 * Revision 1.28  2001/06/05 03:05:41  steve
 *  Add structural addition.
 *
 * Revision 1.27  2001/05/20 00:46:12  steve
 *  Add support for system function calls.
 *
 * Revision 1.26  2001/05/09 02:53:25  steve
 *  Implement the .resolv syntax.
 *
 * Revision 1.25  2001/05/02 23:16:50  steve
 *  Document memory related opcodes,
 *  parser uses numbv_s structures instead of the
 *  symbv_s and a mess of unions,
 *  Add the %is/sub instruction.
 *        (Stephan Boettcher)
 *
 * Revision 1.24  2001/05/02 04:05:17  steve
 *  Remove the init parameter of functors, and instead use
 *  the special C<?> symbols to initialize inputs. This is
 *  clearer and more regular.
 *
 * Revision 1.23  2001/05/01 01:09:39  steve
 *  Add support for memory objects. (Stephan Boettcher)
 *
 * Revision 1.22  2001/04/24 02:23:59  steve
 *  Support for UDP devices in VVP (Stephen Boettcher)
 *
 * Revision 1.21  2001/04/23 00:37:58  steve
 *  Support unconnected .net objects.
 *
 * Revision 1.20  2001/04/18 04:21:23  steve
 *  Put threads into scopes.
 *
 * Revision 1.19  2001/04/14 05:10:56  steve
 *  support the .event/or statement.
 *
 * Revision 1.18  2001/04/05 01:34:26  steve
 *  Add the .var/s and .net/s statements for VPI support.
 *
 * Revision 1.17  2001/04/04 04:33:08  steve
 *  Take vector form as parameters to vpi_call.
 *
 * Revision 1.16  2001/04/02 00:24:30  steve
 *  Take numbers as system task parameters.
 *
 * Revision 1.15  2001/04/01 06:40:45  steve
 *  Support empty statements for hanging labels.
 *
 * Revision 1.14  2001/03/29 03:46:36  steve
 *  Support named events as mode 2 functors.
 *
 * Revision 1.13  2001/03/26 04:00:39  steve
 *  Add the .event statement and the %wait instruction.
 *
 * Revision 1.12  2001/03/25 00:35:35  steve
 *  Add the .net statement.
 *
 * Revision 1.11  2001/03/23 02:40:22  steve
 *  Add the :module header statement.
 *
 * Revision 1.10  2001/03/21 05:13:03  steve
 *  Allow var objects as vpiHandle arguments to %vpi_call.
 *
 * Revision 1.9  2001/03/20 06:16:24  steve
 *  Add support for variable vectors.
 *
 * Revision 1.8  2001/03/20 02:48:40  steve
 *  Copyright notices.
 *
 */
