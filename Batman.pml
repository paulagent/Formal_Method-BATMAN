/*
 * Batman.pml
 *
 * Authors: Cody Doucette and Yvette Tsai
 * May, 2013
 * Boston University CS 512
 *
 * This is a specification of the B.A.T.M.A.N. mobile ad-hoc routing
 * algorithm, implemented in Promela. Using the SPIN verification tool,
 * it verifies various properties guaranteed by the algorithm.
 */

#define SEQ_NUM_MOD   	65536

#define N 			9
#define DEBUG 			0
#define PRINT_RESULTS		1
#define PRINT_PROPERTIES		1

#define	MAX_FAILED_NODES	2
#define TTL			3
#define WINDOW_SIZE		10

#define ORIGINATOR_INTERVAL	20
#define CHANGE_INTERVAL		50
#define GEN_PACKET		10
#define REM_T			100
#define LINK_TIMEOUT		8
#define SIMULATION_END_TIME	300
#define WARM_UP			(SIMULATION_END_TIME / 2)

/* Time. Incremented by time() process. */
int t;
int start;

int messagesIn;
int messagesOut;

typedef LoopCheck {
	bit n[N];
};

mtype = { ogm, data }

/* Receiving buffer of each node. */
chan chans[10] = [50] of { mtype, bit, bit, byte, int, int, int, LoopCheck }


	/****************************************************
	 *
	 *	    B.A.T.M.A.N. Data Structures
	 *
	 */

typedef FailedNodes {

	/* List of currently inactive nodes. */
	int node[MAX_FAILED_NODES];

	/* The number of currently inactive nodes. */
	int numFailed;
}

typedef Neighbors {

	/* List of current direct-link neighbors. */
	int neighs[N];

	/* The number of direct-link neighbors. */
	int numNeighs;

	/* The initial sequence number for this node. */
	int initSeqNum;

	/* The most-recently published sequence number. */
	int lastSeqNum;

	/* Whether the last sequence number wrapped around. */
	bit seqWraparound;

	/* Whether the node is sending the initial sequence number. */
	bit sendingInitSeq;

	/* Whether this node is currently active. */
	bit alive;
};

typedef ChannelStrength {

	/* List of channel strengths to each node. */
	byte to[N];
};

typedef WindowUnit {

	/* The sequence number representing this block in the window. */
	int seqNum;

	/* The number of times this sequence number has been received. */
	byte numRec;
};

typedef Neighbor {

	/* Collection of sequence numbers that are in the sliding window. */
	WindowUnit w[WINDOW_SIZE];

	/* Number of sequence numbers in the sliding window. */
	int packetCount;

	/* Whether the link to this neighbor is unidirectional. */
	bit uni;
};

typedef Originator {

	/* Last time at which this was updated. */
	int lastTime;

	/* Sequence number of the last self-initiated OGM received from a
	 * direct link neighbor. */
	int bidirSeqNum;

	/* The most recent sequence number that has been received. */
	int curSeqNum;

	/* The best first-hop gateway to this destination. */
	int bestLink;

	/* Whether the curSeqNum field is valid. */
	bit curSeqValid;

	/* Information about each direct-link neighbor for this Originator. */ 
	Neighbor neigh[N];
};

typedef OriginatorList {

	/* Each node gets its own copy of information about Originators. */
	Originator node[N];
}

/* Originator lists for every node in the simulation. */
OriginatorList oList[N];

/* List of direct-link neighbors for each node. */
Neighbors node[N];

/* Strengths of every channel. */
ChannelStrength strengthFrom[N];

/* List of failed nodes. */
FailedNodes failed;


	/****************************************************
	 *
	 *     	  Processes and Functions for Sending
	 *
	 */

/*
 * getJitter: returns a random jitter variable in the range [-2...2].
 */
inline getJitter(jitter) {
	if
	:: jitter = -2; :: jitter = -1; :: jitter = 0;
	:: jitter =  1; :: jitter =  2;
	fi;
}

/*
 * calculateBestLink: loop through all of the direct-link neighbors
 * and determine the best first hop to route to the given Originator.
 */
inline calculateBestLink(id, orig) {

	int maxNode = node[id].neighs[0];
	int max = oList[id].node[orig].neigh[maxNode].packetCount;

	int l;
	for (l : 1 .. node[id].numNeighs - 1) {
		int this = node[id].neighs[l];
		if
		:: oList[id].node[orig].neigh[this].packetCount > max ->
			maxNode = this;;
			max = oList[id].node[orig].neigh[maxNode].packetCount;
		:: else -> skip;
		fi;
	}

	oList[id].node[orig].bestLink = maxNode;

}

/*
 * pickNewNeighs: when a node is re-activated, a new set of neighbors is
 * chosen. It picks a node to start with, and then with a high probability
 * also that node's neighbors as its own neighbors to preserve locality in
 * the network. However, it will at least give a node two neighbors, even if
 * they are both random.
 */
inline pickNewNeighs(id) {

	int s;

	/* Pick node s as first neighbor. */
loop:	do
	:: true ->
		if
		:: s = 0; :: s = 1; :: s = 2; :: s = 3; :: s = 4;
		:: s = 5; :: s = 6; :: s = 7; :: s = 8;
		fi;

		if
		:: id == s || node[s].alive == 0 ->
			goto loop;
		:: else ->
			break;
		fi;
	:: else -> skip;
	od;

	node[id].neighs[0] = s;
	node[id].numNeighs = 1;	

	/* With some probability, become neighbors with the neighbors of s. */
	int p;
	bit found = 0;
	for (p : 0 .. node[s].numNeighs - 1) {

		int this = node[s].neighs[p];

		int m;
		for (m : 0 .. node[this].numNeighs - 1) {
			if
			:: id == node[this].neighs[m] -> goto skipNode;
			:: else -> skip;
			fi;
		}

		int add;

		if
		:: add = 1; add = 2; add = 3;
		fi;

		if
		:: node[this].alive == 1 && add >= 2->
			found = 1;
			node[id].neighs[node[id].numNeighs] = this;
			node[id].numNeighs++;
			node[this].neighs[node[this].numNeighs] = id;
			node[this].numNeighs++;
		:: else -> skip;
		fi;
skipNode:

	}

	/* If no neighbors of s were added, then randomly add another node. */
	if
	:: found == 0 ->

reloop:		do
		:: true ->
			if
			:: s = 0; :: s = 1; :: s = 2; :: s = 3;:: s = 4;
			:: s = 5; :: s = 6; :: s = 7; :: s = 8;
			fi;

			for (k : 0 .. node[id].numNeighs - 1) {
				if
				:: id == s || node[id].neighs[k] == s ->
					goto reloop;
				:: else -> skip;
				fi;
			}
			break;
		:: else -> skip;
		od;

		node[id].neighs[node[id].numNeighs] = s;
		node[id].numNeighs++;
		node[s].neighs[node[s].numNeighs] = id;
		node[s].numNeighs++;
	:: else -> skip;
	fi;
}

/*
 * removeFailedNodes: remove all direct-link neighbors which have not
 * been heard from in at least REMOVE_TIME time units.
 */
inline removeFailedNodes(id) {

	bit removed = 0;
	int k;

	for (k : 0 .. node[id].numNeighs - 1) {
		if
		:: t - oList[id].node[node[id].neighs[k]].lastTime >= REM_T ->

			removed = 1;

			if
			:: DEBUG ->
				printf("%d is removing %d.\n",
				id, node[id].neighs[k]);
			:: else -> skip;
			fi;

			int num = node[id].numNeighs;
			int rem = node[id].neighs[k];
			node[id].neighs[k] = node[id].neighs[num - 1];
			node[id].numNeighs--;

			int l;
			for (l : 0 .. N - 1) {
				oList[id].node[l].neigh[rem].packetCount = 0;
			}

			k--;
		:: else -> skip;
		fi;
	}

	if
	:: removed == 1 ->
		for (k : 0 .. N - 1) {
			int orig = k;
			if
			:: id != orig ->
				calculateBestLink(id, orig);
			:: else -> skip;
			fi;
		}
	:: else -> skip;
	fi;

	if
	:: node[id].numNeighs == 0 ->
		pickNewNeighs(id);
		int prob;
		for (k : 0 .. node[id].numNeighs - 1) {
			if
			:: prob = 1; :: prob = 2; :: prob = 3
			:: prob = 4; :: prob = 5;
			fi;
			strengthFrom[id].to[node[id].neighs[k]] = prob;
			if
			:: prob = 1; :: prob = 2; :: prob = 3
			:: prob = 4; :: prob = 5;
			fi;
			strengthFrom[node[id].neighs[k]].to[id] = prob;

			oList[id].node[node[id].neighs[k]].lastTime = t;
			oList[node[id].neighs[k]].node[id].lastTime = t;
		}
	:: else -> skip;
	fi;
}

/*
 * sendOGM: sends an OGM from id to node[id].neighs[i] with some
 * probability of failure.
 */
inline sendOGM(id, i, seqNum) {

	byte prob = strengthFrom[id].to[node[id].neighs[i]];
	byte rand;

	if
	:: rand = 0; :: rand = 1; :: rand = 2 :: rand = 3; :: rand = 4;
	fi;

	if
	:: prob > rand ->
		if
		:: DEBUG ->
			printf("%d -> %d SEND SUCCESS\n",
			id, node[id].neighs[i]);
		:: else -> skip;
		fi;

		/* Property 2: No redundant OGMs. */

		if
		:: PRINT_PROPERTIES ->
			if
			:: !(node[id].sendingInitSeq ||

			    (seqNum > node[id].lastSeqNum &&
			     node[id].seqWraparound == 0) ||

			    (seqNum == 0 && 
			     node[id].lastSeqNum == SEQ_NUM_MOD - 1 &&
			     node[id].seqWraparound == 1)) ->
				printf("Property 2 violated: Node %d is sending an OGM with sequence number %d, but a previous sequence number was also %d.\n",
					id, seqNum, node[id].lastSeqNum);
			:: else -> skip;
			fi;

		:: else ->
atomic {
			assert(node[id].sendingInitSeq ||

				(seqNum > node[id].lastSeqNum &&
				node[id].seqWraparound == 0) ||

				(seqNum == 0 && 
				node[id].lastSeqNum == SEQ_NUM_MOD - 1 &&
				node[id].seqWraparound == 1));
}
		fi;

atomic {
		chans[node[id].neighs[i]]!ogm,1,0,TTL,seqNum,id,id,0;
		messagesIn++;
}
	:: else ->
		if
		:: DEBUG ->
			printf("%d -> %d SEND FAILURE\n",
			id, node[id].neighs[i]);
		:: else -> skip;
		fi;
	fi;
}

/*
 * send: sends a new OGM to all direct neighbors every ORIGINATOR_INTERVAL
 * steps, with some jitter.
 */
proctype send(int id) {

	int expire;
	if
	:: expire = 0;  :: expire = 1;  :: expire = 2;  :: expire = 3;
	:: expire = 4;  :: expire = 5;  :: expire = 6;  :: expire = 7;
	:: expire = 8;  :: expire = 9;  :: expire = 10; :: expire = 11;
	:: expire = 12; :: expire = 13; :: expire = 14; :: expire = 15;
	:: expire = 16; :: expire = 17; :: expire = 18; :: expire = 19;
	fi;

	int jitter, i;
	int seqNum = node[id].initSeqNum;
	bit sent;
	node[id].sendingInitSeq = 1;

	do
	:: t == SIMULATION_END_TIME ->
		break;
	:: t == expire ->

		sent = 0;
		removeFailedNodes(id);

		for (i : 0 .. node[id].numNeighs - 1) {
			if
			:: node[id].alive == 1 ->
				sendOGM(id, i, seqNum);
				sent = 1;
			:: else ->
				goto cont;
			fi;
		}
cont:
		if
		:: sent == 1 ->
			node[id].sendingInitSeq = 0;
			node[id].lastSeqNum = seqNum;
			seqNum = (seqNum + 1) % SEQ_NUM_MOD;
		:: else -> skip;
		fi;

		if
		:: seqNum == 0 -> node[id].seqWraparound = 1;
		:: else -> node[id].seqWraparound = 0;
		fi;
		getJitter(jitter);
		expire = expire + ORIGINATOR_INTERVAL + jitter;
	od;
}


	/****************************************************
	 *
	 *	Processes and Functions for Receiving
	 *
	 */

/*
 * bidirectionalLinkCheck: this check is used to verify that a detected link
 * to a neighbor can be used in both directions.
 */
inline bidirectionalLinkCheck(id, orig, sender, isdir, seqNum) {

	int b;
	if
	:: seqNum > oList[id].node[orig].bidirSeqNum ->
		if
		:: seqNum - oList[id].node[orig].bidirSeqNum <= LINK_TIMEOUT ->
			for (b : 0 .. N - 1) {
				oList[id].node[b].neigh[sender].uni = 0;
			}
		:: else ->
			for (b : 0 .. N - 1) {
				oList[id].node[b].neigh[sender].uni = 1;
			}
		fi;
	:: oList[id].node[orig].bidirSeqNum >= seqNum ->
		if
		:: oList[id].node[orig].bidirSeqNum - seqNum <= LINK_TIMEOUT ->
			for (b : 0 .. N - 1) {
				oList[id].node[b].neigh[sender].uni = 0;
			}
		:: else -> skip;
			for (b : 0 .. N - 1) {
				oList[id].node[b].neigh[sender].uni = 1;
			}
		fi;
	:: else -> skip;
	fi;

	if
	:: isdir == 1 && seqNum >= node[id].lastSeqNum ->
		/* Record the new bidirectional sequence number. */
		oList[id].node[orig].bidirSeqNum = seqNum;
	:: else -> skip;
	fi;
}

/*
 * moveSlidingWindows: moves all direct-link sliding windows to make the
 * current sequence number the new upper bound of each sliding window.
 */
inline moveSlidingWindows(id, orig, seqNum) {

	int oldBound = oList[id].node[orig].curSeqNum;
	int s = seqNum - oldBound;
	int i, j;

	if
	:: s >= WINDOW_SIZE ->

		for (j : 0 .. N - 1) {
			for (i : 0 .. WINDOW_SIZE - 1) {
				oList[id].node[orig].neigh[j].w[i].numRec = 0;
				oList[id].node[orig].neigh[j].w[i].seqNum =
				seqNum - WINDOW_SIZE + i + 1;
			}
			oList[id].node[orig].neigh[j].packetCount = 0;
		}

	:: s < WINDOW_SIZE && s > 0 ->

		for (j : 0 .. N - 1) {
			for (i : 0 .. WINDOW_SIZE - s - 1) {
				oList[id].node[orig].neigh[j].w[i].seqNum =
				oList[id].node[orig].neigh[j].w[i + s].seqNum;

				oList[id].node[orig].neigh[j].w[i].numRec =
				oList[id].node[orig].neigh[j].w[i + s].numRec;
			}
			int x = WINDOW_SIZE - 1;

			for (i : 0 .. s - 1) {
				oList[id].node[orig].neigh[j].w[x-i].seqNum =
				seqNum - i;
				oList[id].node[orig].neigh[j].w[x-i].numRec = 0;
				
			}

			oList[id].node[orig].neigh[j].w[x].numRec++;

			int sum = 0;
			for (i : 0 .. WINDOW_SIZE - 1) {
				sum = sum + 
				oList[id].node[orig].neigh[j].w[i].numRec;
			}
			oList[id].node[orig].neigh[j].packetCount = sum;
		}
	:: else -> assert(0);
	fi;

}

/*
 * updateSeqNumCount: update the appropriate sequence number in the sliding
 * window for this neighbor.
 */
inline updateSeqNumCount(id, orig, sender, seqNum) {

	int k;
	for (k : 0 .. WINDOW_SIZE - 1) {

		if
		:: oList[id].node[orig].neigh[sender].w[k].seqNum == seqNum ->
			oList[id].node[orig].neigh[sender].w[k].numRec++;
			goto done;
		:: else -> skip;
		fi;
	}
	assert(0);
done:
	/* Increment the number of packets received on this link. */
	oList[id].node[orig].neigh[sender].packetCount++;
}

/*
 * rebOGM: rebroadcast an OGM to all direct-link neighbors.
 */
inline rebOGM(id, orig, sender, isdir, unidir, ttl, seqNum, m) {

	byte prob = strengthFrom[id].to[node[id].neighs[m]];
	bit uni = oList[id].node[orig].neigh[sender].uni;
	bit direct;

	if
	:: uni -> goto dropUni;
	:: else -> skip;
	fi;

	/* Only send a packet with the is-direct-link flag set if
	 * the OGM received had the flag set and if we're replying
	 * to that Originator. */
	if
	:: isdir && node[id].neighs[m] == sender -> direct = 1;
	:: else -> direct = 0;
	fi;

	byte rand;
	if
	:: rand = 0; :: rand = 1; :: rand = 2; rand = 3; rand = 4;
	fi;

	if
	:: prob > rand ->
		if
		:: DEBUG ->
			printf("%d -> %d REBROADCAST SUCCESS\n",
			id, node[id].neighs[m]);
		:: else -> skip;
		fi;

atomic {
		chans[node[id].neighs[m]]!ogm,direct,0,ttl-1,seqNum,orig,id,0;
		messagesIn++;
}
	:: else -> 
		if
		:: DEBUG ->
			printf("%d -> %d REBROADCAST FAILURE\n",
			id, node[id].neighs[m]);
		:: else -> skip;
		fi;
	fi;
dropUni:

}

/*
 * handlePacket: forward the given data to the best link available.
 */
inline handlePacket(id, isdir, unidir, ttl, seqNum, orig, lc) {

	/* Property 4: No routing loops. */
	if
	:: PRINT_PROPERTIES ->
		if
		:: lc.n[id] != 0 ->
			printf("Property 4 violated: Packet has already previously visited node %d; routing loop detected.\n",
				id);
			goto error;
		:: else -> skip;
		fi;
	:: else ->
		assert(lc.n[id] == 0);
	fi;
	lc.n[id] = 1;

	int best = oList[id].node[orig].bestLink;

	if
	:: best == -1 && node[id].numNeighs > 0 ->
		best = node[id].neighs[0];
	:: best == -1 && node[id].numNeighs == 0 ->
		goto error;
	:: else -> skip;
	fi;

	/* Property 5: No unidirectional links in forwarding. */
	if
	:: PRINT_PROPERTIES ->
		if
		:: oList[id].node[orig].neigh[best].uni != 0 ->
			printf("Property 5 violated: The link between node %d and node %d is unidirectional.\n",
				id, best);
		:: else -> skip;
		fi;
	:: else ->
		assert(oList[id].node[orig].neigh[best].uni == 0);
	fi;

	byte rand;
	if
	:: rand = 0; :: rand = 1; :: rand = 2 :: rand = 3; :: rand = 4;
	fi;

	int b;
	byte prob;
	for (b : 0 .. N - 1) {
		if
		:: best == node[id].neighs[b] ->
			prob = strengthFrom[id].to[node[id].neighs[b]];
		:: else -> skip;
		fi;
	}

	/* Property 3: Correctness of routing. */
	if
	:: PRINT_PROPERTIES ->
		for (b : 0 .. node[id].numNeighs - 1) {
			int this = node[id].neighs[b];
			if
			:: (oList[id].node[orig].neigh[best].packetCount <
			    oList[id].node[orig].neigh[this].packetCount) ->
				printf("Property 3 violated: Link %d has a higher packet count than link %d, but the best link is currently %d.\n",
					this, best, best);
			:: else -> skip;
			fi;
		}
	:: else ->
atomic {
		for (b : 0 .. node[id].numNeighs - 1) {
			int this = node[id].neighs[b];
			assert(oList[id].node[orig].neigh[best].packetCount >=
				oList[id].node[orig].neigh[this].packetCount);
		}
}
	fi;

	if
	:: rand < prob ->
atomic {
		chans[best]!data,isdir,unidir,ttl,seqNum,orig,id,lc;
		messagesIn++;
		goto out;
}
	:: else -> skip;
	fi;

error:



out:
}

/*
 * receive: receives a packet and forwards it if its data or processes
 * it if it's a B.A.T.M.A.N. Originator Message.
 */
proctype receive(int id) {

	mtype type;
	bit isdir, unidir;
	byte ttl;
	int seqNum, orig, sender;
	LoopCheck lc;

	do
	:: t == SIMULATION_END_TIME ->
		break;
	:: len(chans[id]) ->

atomic {
		chans[id]?type,isdir,unidir,ttl,seqNum,orig,sender,lc;
		messagesOut++;
}
		oList[id].node[sender].lastTime = t;

		if
		:: type == data ->
			/* Interpret orig as destination, id as source,
			 * and all other fields as data. */
			handlePacket(id, isdir, unidir, ttl, seqNum, orig, lc);
			goto end;
		:: else -> skip;
		fi;

		/* Packet is invalid. */
		if
		:: sender == id || unidir == 1 -> goto drop;
		:: else -> skip;
		fi;

		/* If this originated from this node, perform a
		 * bidirectional link check and drop. */
		if
		:: orig == id ->
			bidirectionalLinkCheck(id, orig, sender, isdir, seqNum);
			goto drop;
		:: else -> skip;
		fi;	

		if
		:: oList[id].node[orig].curSeqValid == 0 ->
			oList[id].node[orig].curSeqValid = 1;
			oList[id].node[orig].curSeqNum =
			oList[id].node[orig].neigh[0].w[WINDOW_SIZE - 1].seqNum;
		:: else -> skip;
		fi;

		if
		/* If the OGM has been received on a bidirectional link and
		 * if it contains a new sequence number, then update the most
		 * current sequence number, move the sliding windows to it,
		 * update the appropriate sequence number count, and calculate
		 * the best link (if it changes). */
		:: unidir != 1 && oList[id].node[orig].curSeqNum < seqNum ->

			moveSlidingWindows(id, orig, seqNum);
			oList[id].node[orig].curSeqNum = seqNum;
			calculateBestLink(id, orig);

		/* If the received sequence number is in the window, update
		 * the appropriate sequence number count and calculate the
		 * best link (if it changes). */
		:: oList[id].node[orig].curSeqNum >= seqNum &&
		   seqNum > oList[id].node[orig].curSeqNum - WINDOW_SIZE ->

			updateSeqNumCount(id, orig, sender, seqNum);
			calculateBestLink(id, orig);

		/* If the packet is out of the sliding window range, ignore. */
		:: else -> skip;
		fi;

		if
		:: ttl == 1 -> goto drop;
		:: else -> skip;
		fi;

		/* Rebroadcast this OGM to all direct-link neighbors. */
		int m;
		for (m : 0 .. node[id].numNeighs - 1) {
			rebOGM(id, orig, sender, isdir, unidir, ttl, seqNum, m);
		}
		goto end;
drop:
		if
		:: DEBUG ->
			printf("PACKET DROPPED\n");
		:: else -> skip;
		fi;
end:
	od;
}


	/****************************************************
	 *
	 *	Processes and Functions for Model State
	 *
	 */

/*
 * selectNodeToActive: Selects the index of a failed node in the failed
 * nodes array to activate.
 */
inline selectNodeToActivate(id) {

	if
	:: failed.numFailed == 1 ->
		index = 0;
	:: failed.numFailed == 2 ->
		if
		:: index = 0; :: index = 1;
		fi;
	:: failed.numFailed == 3 ->
		if
		:: index = 0; :: index = 1; :: index = 2;
		fi;
	:: else -> skip;
	fi;
}

/*
 * selectNodeToFail: selects a currently-active node to declare inactive.
 */
inline selectNodeToFail(id) {

	int n;

repeat:	do
	:: true ->
		if
		:: n = 0; :: n = 1; :: n = 2; :: n = 3; :: n = 4;
		:: n = 5; :: n = 6; :: n = 7; :: n = 8;
		fi;
		int q;
		for (q : 0 .. failed.numFailed - 1) {
			if
			:: failed.node[q] == n -> goto repeat;
			:: else -> skip;
			fi;
		}
		break;
	:: else -> break;
	od;
	id = n;
}

/*
 * alterNetwork: instantiated every CHANGE_INTERVAL steps to add and/or
 * delete a node from the network.
 */
inline alterNetwork() {

	int rand, id, k;

	if
	:: rand = 0; :: rand = 1;
	fi;

	if		/* Choose an inactive node to activate. */
	:: rand == 1 && failed.numFailed > 0 ->

atomic {
		int index;
		selectNodeToActivate(index)
		id = failed.node[index];

		if
		:: DEBUG ->
			printf("Chosen to activate: %d\n", id);
		:: else -> skip;
		fi;

		failed.node[index] = failed.node[failed.numFailed - 1];
		failed.numFailed--;

		pickNewNeighs(id);

		int prob;
		for (k : 0 .. node[id].numNeighs - 1) {
			if
			:: prob = 1; :: prob = 2; :: prob = 3
			:: prob = 4; :: prob = 5;
			fi;
			strengthFrom[id].to[node[id].neighs[k]] = prob;
			if
			:: prob = 1; :: prob = 2; :: prob = 3
			:: prob = 4; :: prob = 5;
			fi;
			strengthFrom[node[id].neighs[k]].to[id] = prob;

			
			oList[id].node[node[id].neighs[k]].lastTime = t;
			oList[node[id].neighs[k]].node[id].lastTime = t;
		}
		node[id].alive = 1;
}
	:: else ->	/* Do not activate any nodes. */
		skip;
	fi;

	if
	:: rand = 0; :: rand = 1;
	fi;

	if		/* Choose a node to deactivate. */
	:: rand == 1 && failed.numFailed < MAX_FAILED_NODES ->

atomic {
		selectNodeToFail(id);
		node[id].alive = 0;

		if
		:: DEBUG ->
			printf("Chosen to fail: %d\n", id);
		:: else -> skip;
		fi;

		failed.node[failed.numFailed] = id;
		failed.numFailed++;

		for (k : 0 .. node[id].numNeighs - 1) {
			strengthFrom[id].to[node[id].neighs[k]] = 0;
			strengthFrom[node[id].neighs[k]].to[id] = 0;
		}

		node[id].numNeighs = 0;
		for (k : 0 .. N - 1) {
			oList[id].node[k].bestLink = -1;
			int l;
			for (l : 0 .. N - 1) {
				oList[id].node[k].neigh[l].packetCount = 0;
			}
		}

}
	:: else ->	/* Do not deactivate any nodes. */
		skip;
	fi;
}

/*
 * generatePacket: generates a packet between a random source and destination
 * every GEN_PACKET time units.
 */
inline generatePacket() {

	int src, dst;

	if
	:: src = 0; :: src = 1; :: src = 2; :: src = 3; :: src = 4;
	:: src = 5; :: src = 6; :: src = 7; :: src = 8;
	fi;

	do
	:: true ->
		if
		:: dst = 0; :: dst = 1; :: dst = 2; :: dst = 3; :: dst = 4;
		:: dst = 5; :: dst = 6; :: dst = 7; :: dst = 8;
		fi;

		if
		:: src != dst -> break;
		:: else -> skip;
		fi;
	:: else -> skip;
	od;

	LoopCheck lc;

atomic {
	chans[src]!data,0,0,0,0,src,dst,lc;
	messagesIn++;
}

}

/*
 * checkNumMessages: checks that the number of messages that have entered
 * the network is equal to the messages that have left plus the messages
 * that are still active.
 */
inline checkNumMessages() {

	int sum = 0;
	int u;
	for (u : 0 .. N - 1) {
		sum = sum + len(chans[u]);
	}

	/* Property 1: All messages that enter the network eventually leave. */
	if
	:: PRINT_PROPERTIES ->
		if
		:: messagesIn != messagesOut + sum ->
			printf("Property 1 violated: Total messages entered into the network is %d, but the total messages that have left or are currently inside the network is %d.\n",
				messagesIn, messagesOut + sum);
		:: else -> skip;
		fi;
	:: else ->
		assert(messagesIn == messagesOut + sum);
	fi;
}

/*
 * time: process to increment a time variable until SIMULATION_END_TIME.
 */
proctype time() {

	start == 1;
	t = 0;
	int counter = 1;

	do
	:: (t == SIMULATION_END_TIME) ->
		if
		:: PRINT_RESULTS ->

			int i, j;
			for (i : 0 .. N - 1) {

				printf("%d has %d neighbors: \n",
				i, node[i].numNeighs);

				for (j : 0 .. node[i].numNeighs - 1) {
					printf("%d\n", node[i].neighs[j]);
				}

				printf("\n");

				for (j : 0 .. N - 1) {
					printf("Best link to %d is via %d\n",
					j, oList[i].node[j].bestLink);
				}
				printf("\n\n");
			}
		:: else -> skip
		fi;

		break;
	:: (counter % 1000 == 0) ->
		t++;
		counter = 1;

		if
		:: t % CHANGE_INTERVAL == 0 ->
			alterNetwork();
		:: else -> skip;
		fi;

		if
		:: t >= WARM_UP && t % GEN_PACKET == 0 ->
			generatePacket();
		:: else -> skip;
		fi;

	:: else ->
		counter = counter + 1;
atomic {
		checkNumMessages();
}
	od;
}


	/****************************************************
	 *
	 *	     Data Initializing Functions
	 *
	 */

/*
 * setNeighbors: Statically set up the neighbors of all nodes [0...8].
 */
inline setNeighbors() {
	node[0].neighs[0] = 1; node[0].neighs[1] = 3;
	node[0].numNeighs = 2;

	node[1].neighs[0] = 0; node[1].neighs[1] = 2; node[1].neighs[2] = 4;
	node[1].numNeighs = 3;

	node[2].neighs[0] = 1; node[2].neighs[1] = 5;
	node[2].numNeighs = 2;

	node[3].neighs[0] = 0; node[3].neighs[1] = 4; node[3].neighs[2] = 6;
	node[3].numNeighs = 3;

	node[4].neighs[0] = 1; node[4].neighs[1] = 3; node[4].neighs[2] = 5;
	node[4].neighs[3] = 7;
	node[4].numNeighs = 4;

	node[5].neighs[0] = 2; node[5].neighs[1] = 4; node[5].neighs[2] = 8;
	node[5].numNeighs = 3;

	node[6].neighs[0] = 3; node[6].neighs[1] = 7;
	node[6].numNeighs = 2;

	node[7].neighs[0] = 4; node[7].neighs[1] = 6; node[7].neighs[2] = 8;
	node[7].numNeighs = 3;

	node[8].neighs[0] = 5; node[8].neighs[1] = 7;
	node[8].numNeighs = 2;
}


/*
 * setChannelStrengths: set all channel strengths to be at 100%.
 */
inline setChannelLossiness() {

	int i, j, prob;

	for (i : 0 .. N - 1) {
		node[i].alive = 1;
		for (j : 0 .. node[i].numNeighs - 1) {

			if
			:: prob = 1; :: prob = 2; :: prob = 3;
			:: prob = 4; :: prob = 5;
			fi;

			strengthFrom[i].to[node[i].neighs[j]] = prob;
			oList[i].node[j].lastTime = 0;
		}
	}
}

/*
 * setInitSeqNums: altered by a python script to randomly assign initial
 * sequence numbers for eac noe.
 */
inline setInitSeqNums() {
	node[0].initSeqNum = 27254;
	node[1].initSeqNum = 9341;
	node[2].initSeqNum = 44523;
	node[3].initSeqNum = 10856;
	node[4].initSeqNum = 10240;
	node[5].initSeqNum = 8403;
	node[6].initSeqNum = 59999;
	node[7].initSeqNum = 13090;
	node[8].initSeqNum = 60936;

	node[0].lastSeqNum = 0;
	node[1].lastSeqNum = 0;
	node[2].lastSeqNum = 0;
	node[3].lastSeqNum = 0;
	node[4].lastSeqNum = 0;
	node[5].lastSeqNum = 0;
	node[6].lastSeqNum = 0;
	node[7].lastSeqNum = 0;
	node[8].lastSeqNum = 0;
}

/*
 * setInitWindows: initialize all sliding windows in the network.
 */
inline setInitWindows() {

	int i, j, k, l;
	for (i : 0 .. N - 1) { for (j : 0 .. N - 1) { for (k : 0 .. N - 1) {
		for (l : 0 .. WINDOW_SIZE - 1) {
			oList[i].node[j].neigh[k].w[l].seqNum =
				node[j].initSeqNum - WINDOW_SIZE + l + 1;

		}		
	} } }

}

/*
 * setBestLinks: initialize all best links in the network to be no
 * preferred node.
 */
inline setBestLinks() {

	int i, j;
	for (i : 0 .. N - 1) {
		for (j : 0 .. N - 1) {
			oList[i].node[j].bestLink = -1;
		}
	}
}

init {

	setNeighbors();
	setChannelLossiness();
	setInitSeqNums();
	setInitWindows();
	setBestLinks();

	messagesIn = 0;
	messagesOut = 0;

	run time();

	int i;
	for (i : 0 .. N - 1) {
		run receive(i);
	}
	for (i : 0 .. N - 1) {
		run send(i);
	}
	start = 1;
}

