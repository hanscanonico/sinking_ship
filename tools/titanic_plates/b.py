"""B deck, the bridge deck, as the Titanic sailed in April 1912 (#360, #367).

Plate IV (The Shipbuilder, June 1911, leaf n318) draws the Olympic's B deck, a
first-class promenade down both her sides. The Titanic's was not: "On the bridge deck B
the deckhouses have been extended to provide increased first-class accommodation, as will
be seen from the plan of this deck given in Fig. 2, which should be compared with the
corresponding deck plan of the Olympic given in Plate IV of our special number. Two
private promenade decks have been instituted in connection with the parlour suite rooms
... On the same deck a Cafe Parisien, which is an entirely new feature on board ship, has
been arranged in connection with the restaurant ... a reception room has also been
provided in connection with the restaurant" — The Shipbuilder, vol. VI (1911-12), "The
White Star Liner Titanic", pp. 221-224. Its Fig. 2, "First-class accommodation on bridge
deck B", draws her B deck from her restaurant's after wall to her house's front, room by
room, berth by berth, across pp. 222-223 (Internet Archive the_shipbuilder_vol6, leaves
n237 and n238, Public Domain Mark 1.0; plates.tsv SB6-222, SB6-223). So her B deck is
read in three parts, each in its own view's pixels:

    b_aft   Plate IV: her after end, her second-class houses and promenades, and her whole
            deck's outline, which the 1912 plan does not draw;
    b_mid   Fig. 2, p. 222: her restaurant, its Cafe Parisien and reception room, her
            after suites, to the gutter;
    b_fwd   Fig. 2, p. 223: from the gutter, her parlour suites and their private
            promenades, the forward entrance, her forward cabins, to her house's front.

The parts meet on the walls both draw (deck.py's JOIN): the restaurant's after wall and
the second-class staircase's well (Plate IV and p. 222), and the wall at the gutter (pp.
222 and 223, which overlap there by about 240 px). The 1912 inquiry's "principal
staterooms of the vessel, 97 in number, having berths for 198 passengers" (BOT) is the
check on the rooms: what Fig. 2 draws is what is laid, a cabin's berths as its bed boxes
number them.
"""
PARTS = ["b_aft", "b_mid", "b_fwd"]
