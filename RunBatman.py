#
# RunBatman.py
#
# Authors: Cody Doucette and Yvette Tsai
# May 6, 2013
# Boston University CS 512
#
# This is a script to wrok with FILENAME. Batman.pml is a 
# specification of the B.A.T.M.A.N. mobile ad-hoc 
# routing algorithm, implemented in Promela. This script
# set up some initial parameters and then call SPIN to 
# perform verification. 
#
# ---------------------------------------------------------
#
# Run the script with an example of 9 nodes network
#   python Batman.pml
#   The output file will be created with filename 
#   "Batman_OUTPUT.txt"
# 
# Run the script with desire number of NxN matrix network, 
#   where N in an interger greater or equl to 2
#   python Batman_Template.pml N
#   The output file will be created with filename 
#   "Batman_Template_Nodes_N_OUTPUT.txt"
# 
# '-p' 
#   Add the PRINT PROPERTIES flag to include the 
#   properties in the output file
#
# '-r' 
#   Add the PRINT RESULT flag to include the
#   result in the output file
#

import random, os, sys

if __name__ == '__main__': 
    
    # range of sequence number [0,2^16-1]
    a = 0
    b = 65535

    # flags for differenct test run output
    testsample = False
    printResult = False
    printProperties = False
    N = 0

    # read in all command line input
    args = sys.argv

    # the path to the file we want to modift
    filename = args[1]

    # user can input number of nodes in the network
    if(filename == "Batman.pml" or filename == "Batman_Violation.pml"):
        testsample = True
    else:
        for i in range(2,len(args)):
            if(args[i].isdigit()):
                N = int(args[i])
                N2 = N*N
        if(N == 0):
            print 'Invalid Command, need to specify number of nodes'
            sys.exit()
        elif(N < 3):
            print 'Inavlid number of nodes'
            sys.exit()

    # user specifies to print out the result
    if("-r" in args):
        printResult = True
    
    # user specifies to print out the properties
    if("-p" in args):
        printProperties = True


    lineBuffer = []

    fin = open(filename,'r')

    # if the user enter the example file, we only
    # modify the initial sequence numner step
    if(testsample):
        for line in fin:
            if(printResult and "#define PRINT_RESULTS" in line):
                lineBuffer.append("#define PRINT_RESULTS\t\t1\n")
                printResult = False
            elif(printProperties and "#define PRINT_PROPERTIES" in line):
                lineBuffer.append("#define PRINT_PROPERTIES\t\t1\n")
                printProperties = False
            elif("node[" in line and "].initSeqNum = " in line):
                s = line.rstrip().split("=")[0]
                lineBuffer.append('%s %d;\n' % (s + "=",random.randint(a,b)))
            else:
                lineBuffer.append(line)
    # if the user enter a specific number of nodes, we produce
    # an initial N x N matrix network with N*N nodes
    else:
        defN = False
        iniChan = False 
        selFail = False
        picFirstNei = False
        picSecNei = False
        setSrc = False
        setDst = False
        iniSetNei = False
        iniSeqNum = False

        for line in fin:
            if(not defN and "#define N" in line):
                lineBuffer.append("%s \t\t\t%d\n" % ("#define N ",N2))
                defN = True
            elif(printResult and "#define PRINT_RESULTS" in line):
                lineBuffer.append("#define PRINT_RESULTS\t\t1\n")
                printResult = False
            elif(printProperties and "#define PRINT_PROPERTIES" in line):
                lineBuffer.append("#define PRINT_PROPERTIES\t\t1\n")
                printProperties = False
            elif(not iniChan and "INSERT INITIAL RECEIVING BUFFER" in line):
                lineBuffer.append("chan chans[%d] = [%d] of " % (N2+1, 5*N2+5))
                lineBuffer.append("{ mtype, bit, bit, byte, int, int, int, LoopCheck }\n")
                iniChan = True
            elif(not selFail and "INSERT RANDOM SELECT FAIL NODE" in line):
                for i in range(0,N2):
                    lineBuffer.append("\t\t:: n = %d;\n" % (i))
                selFail = True
            elif(not picFirstNei and "INSERT RANDOM PICK FIRST NEIGHBOR" in line):
                for i in range(0, N2):
                    lineBuffer.append("\t\t:: s = %d;\n" % (i))
                picFirstNei = True
            elif(not picSecNei and "INSERT RANDOM PICK SECOND NEIGHBOR" in line):
                for i in range(0, N2):
                    lineBuffer.append("\t\t\t:: s = %d;\n" % (i))
                picSecNei = True
            elif(not setSrc and "INSERT RANDOM SELECT PACKET SOURCE" in line):
                for i in range(0,N2):
                    lineBuffer.append("\t:: src = %d;\n" % (i))
                setSrc = True
            elif(not setDst and "INSERT RANDOM SELECT PACKET DESTINATION" in line):
                for i in range(0,N2):
                    lineBuffer.append("\t\t:: dst = %d;\n" % (i))
                setDst = True
            elif(not iniSetNei and "INSERT INITIAL NEIGHBOR SETTING" in line):

                alreadyInit = [0, N-1, N2-N, N2-1]

                # initial neighbor for upper left corner node
                lineBuffer.append("\tnode[0].neighs[0] = 1; ")
                lineBuffer.append("node[0].neighs[1] = %d;\n" % (N))
                lineBuffer.append("\tnode[0].numNeighs = 2;\n\n")
                # initial neighbor for upper right corner node
                lineBuffer.append("\tnode[%d].neighs[0] = %d; " % (N-1, N-2))
                lineBuffer.append("node[%d].neighs[1] = %d;\n" % (N-1, 2*N-1))
                lineBuffer.append("\tnode[%d].numNeighs = 2;\n\n" % (N-1))
                # initial neighbor for lower left corner node
                lineBuffer.append("\tnode[%d].neighs[0] = %d; " % (N2-N, N2-2*N))
                lineBuffer.append("node[%d].neighs[1] = %d;\n" % (N2-N, N2-N+1))
                lineBuffer.append("\tnode[%d].numNeighs = 2;\n\n" % (N2-N))
                # initial neighbor for lower right corner node
                lineBuffer.append("\tnode[%d].neighs[0] = %d; "% (N2-1, N2-1-N))
                lineBuffer.append("node[%d].neighs[1] = %d;\n" % (N2-1, N2-2))
                lineBuffer.append("\tnode[%d].numNeighs = 2;\n\n" % (N2-1))

                # for first row of degree 3 neighbor
                for i in range(1,N-1):
                    alreadyInit.append(i)
                    lineBuffer.append("\tnode[%d].neighs[0] = %d; " % (i, i-1))
                    lineBuffer.append("node[%d].neighs[1] = %d; " % (i,i+N))
                    lineBuffer.append("node[%d].neighs[2] = %d;\n" % (i,i+1))
                    lineBuffer.append("\tnode[%d].numNeighs = 3;\n\n" % (i))
                # for last row of degree 3 neighbor
                for i in range(N2-N+1, N2-1):
                    alreadyInit.append(i)
                    lineBuffer.append("\tnode[%d].neighs[0] = %d; " % (i, i-1))
                    lineBuffer.append("node[%d].neighs[1] = %d; " % (i,i-N))
                    lineBuffer.append("node[%d].neighs[2] = %d;\n" % (i,i+1))
                    lineBuffer.append("\tnode[%d].numNeighs = 3;\n\n" % (i))
                # for first column of degree 3 neighbor
                for i in range(N, N2-N, N):
                    alreadyInit.append(i)
                    lineBuffer.append("\tnode[%d].neighs[0] = %d; " % (i, i-N))
                    lineBuffer.append("node[%d].neighs[1] = %d; " % (i,i+1))
                    lineBuffer.append("node[%d].neighs[2] = %d;\n" % (i,i+N))
                    lineBuffer.append("\tnode[%d].numNeighs = 3;\n\n" % (i))
                # for last column of degree 3 neighbor
                for i in range(2*N-1, N2-1, N):
                    alreadyInit.append(i)
                    lineBuffer.append("\tnode[%d].neighs[0] = %d; " % (i, i-N))
                    lineBuffer.append("node[%d].neighs[1] = %d; " % (i,i-1))
                    lineBuffer.append("node[%d].neighs[2] = %d;\n" % (i,i+N))
                    lineBuffer.append("\tnode[%d].numNeighs = 3;\n\n" % (i))

                # for rest of degree 4 neighbor
                for i in range(0,N2):
                    if(i not in alreadyInit):
                        lineBuffer.append("\tnode[%d].neighs[0] = %d; " % (i, i-N))
                        lineBuffer.append("node[%d].neighs[1] = %d; " % (i,i+1))
                        lineBuffer.append("node[%d].neighs[2] = %d;\n" % (i,i+N))
                        lineBuffer.append("\tnode[%d].neighs[3] = %d;\n" % (i,i-1))
                        lineBuffer.append("\tnode[%d].numNeighs = 4;\n\n" % (i))
                iniSetNei = True
            elif(not iniSeqNum and "INSERT RANDOM ASSIGN SEQUENCE NUMNER" in line):
                for i in range(0,N2):
                    lineBuffer.append("\tnode[%d].initSeqNum = %d;\n" % (i, random.randint(a,b)))
                lineBuffer.append("\n\n")
                for i in range(0,N2):
                    lineBuffer.append("\tnode[%d].lastSeqNum = 0;\n" % (i))
                iniSeqNum = True
            else:
                lineBuffer.append(line)
    fin.close()

    if(not testsample):
        filename = filename.split(".")[0] + "_Nodes_" + str(N) + ".pml"
    
    # write the file with initial statement inserted
    fout = open(filename,'w+')
    for e in lineBuffer:
        fout.write(e)
    fout.close()

    # run SPIN
    fResult = filename.split(".")[0] + "_OUTPUT.txt"
    os.system("spin %s > %s" % (filename, fResult))
