BATMAN Protocol Promela Model with Spin Checker
================================================
Goal:
  - Become familiar w/ model checker and analyzer  
  - Choose a specific domain of networking, Routing in mobile ad-hoc networks 
  - Formalize safety and correctness properties   
  - Make use of formalizing tool, model checker SPIN Confirm counter-example assertion 
    with violation of each property is inserted 

About:
  This is a Formal Method's class project supervised under 
  Prof. Assaf Kfoury and Rick Skowyra. In this project we use 
  verification modeling language and model checker to implement 
  Network Properties. A Better Approach To Mobile Ad-Hoc 
  Networking (B.A.T.M.A.N.) is a routing protocol specifically 
  designed for networks with dynamic membership, asymmetric 
  connections, and frequent packet loss. In this software, we 
  implement the BATMAN v0.2 protocol with Promela and check it 
  with Spin. 


Last Update:
  May 06, 2013


Authors:
  Cody Doucette, doucette@bu.edu
  Yvette Tsai, ytsai@bu.edu


Software Requirement:
  - Spin Model Checker
    You can install Spin from http://spinroot.com/spin/whatispin.html
  - Python  
    You can install Python from http://www.python.org/getit/


In This Package:
  - Batman.pml: 
    The nine nodes network example program
  - Batman_Violation.pml:
	  The nine nodes network program with series of violation to teaser
    the assertion test
  - Batman_Template.pml:
	  The user specifies number of nodes N*N program 
  - RunBatman.py:
	  Helper script to take care of random number assignment to Promela
    model and flags assignment

Run the Program:
  1. Run provided nine nodes network example (at command prompt $): 

	  $ python RunBatman.py Batman.pml [-r] [-p]

  2. Run provided nine nodes network with violation example:

	  $ python RunBatman.py Batman_Violation.pml [-r] [-p] 

  options 1 and 2 have the network model looks like the following,

	  0 -- 1 -- 2
	  |    |	  |
	  3 -- 4 -- 5
	  |    |	  |
	  6 -- 7 -- 8

  3. Run N*N nodes network (where N is integer):
	
	  $ python RunBatman.py Batman_Template.pml N [-r] [-p]

  option 3 has the network model looks like the following,

	  0 --- 1 --- --- --- N-1
	  |     |    |   |     |
	  N ---N+1--- --- ---2*N-1
	  |     |    |   |     |
	  |     |    |   |     |
    N*N-N--- ---- --- ---N*N-1

  which is a NxN matrix network with N*N nodes

  The -r and -p flags are for user's best interest to see what 
    is in the network model.

  The -r option, when specified, will includes all the routing 
    tables at the end of the simulation in the output file. 
    Otherwise, by default, the routing tables are not included 
    in the output file.

  The -p option, when specified, will turn off the assertions, 
    which will stop the program if false, and instead will just
    include which properties succeeded and 	which did not in the 
    output file. By default, the assertion is off. 

Website:
  http://bucs512.wordpress.com/

