# Hearts — Rules (authoritative source of truth)

Classic 4-player Hearts. Avoid points. Lowest score wins.

## 1. Objective
Finish the match with the lowest total score. Each heart taken costs 1 point;
the Queen of Spades costs 13 points. First player to reach 100 ends the match.

## 2. Setup
- 4 players, standard 52-card deck, no jokers.
- 13 cards dealt to each player, one at a time around the table.
- Hands are sorted by suit, then rank.

## 3. Turn order
- Seats play clockwise: seat 0 → 1 → 2 → 3 → 0.
- Before each hand (except hold hands), every player passes 3 cards
  simultaneously, then play begins.
- The holder of the 2♣ leads the first trick of each hand.
- The winner of each trick leads the next trick.

## 4. Legal moves
- The opening lead of a hand MUST be the 2♣.
- A player must follow the led suit if they hold any card of that suit.
- If unable to follow suit, any card may be played (subject to §5).
- Hearts may be led only after hearts are broken (a heart was played on an
  earlier trick) or when the leader holds nothing but hearts.
- Passing: exactly 3 cards, exchanged simultaneously before play.

## 5. Illegal moves
- Leading anything other than the 2♣ on the first trick.
- Failing to follow suit while holding the led suit.
- Playing a heart or the Q♠ on the FIRST trick while holding a non-point card.
- Leading hearts before they are broken while holding non-heart cards.
- Passing fewer or more than 3 cards.
Illegal attempts are rejected with a message; the game state never changes.

## 6. Captures
- Highest card of the LED suit wins the trick (rank order 2..A; suits have no
  rank). The winner collects all 4 cards and leads next.
- There is no trump suit.

## 7. Special rules
- **Pass rotation:** hand 1 passes left, hand 2 passes right, hand 3 passes
  across, hand 4 is a hold hand (no passing); then the cycle repeats.
- **Hearts broken:** once any heart is played on a trick, hearts may be led.
- **Shooting the moon:** a player who takes ALL 26 points in one hand scores 0
  for the hand; every other player scores +26.

## 8. Scoring
- Each heart taken: 1 point. Queen of Spades taken: 13 points.
- Points accumulate across hands into match totals.
- Moon shot: shooter 0, all others +26 for that hand.

## 9. Winning conditions
- The match ends after the hand in which any player reaches 100+ points.
- The player with the LOWEST total wins. Ties share the win.

## 10. Draw conditions
- Exact tie for the lowest total at match end = shared victory. No tiebreaks.

## 11. AI strategy
- **Easy:** random legal passes and plays.
- **Medium:** dumps dangerous cards when passing (Q♠, A♠/K♠, high hearts,
  short-suit cards); ducks tricks by shedding points without winning; leads
  low from the longest safe suit; never leads A♠/K♠ while the Q♠ is unaccounted
  for.
- **Hard:** everything in Medium, plus keeps moon-worthy hands together when
  passing, detects an opponent shooting the moon (points taken in every trick)
  and breaks it by taking a point trick, and plays low to keep late control.

## 12. Edge cases
- A player holding only hearts may lead hearts even if unbroken.
- A player holding only point cards on the first trick may play them.
- If the Q♠ holder cannot follow suit on the first trick and holds other
  non-point cards, the Q♠ stays in hand.
- Pause/app background freezes all engine timers; resume continues the exact
  phase — never a lost turn.
- The watchdog re-enters any phase found without a live timer and without a
  pending human decision; trick resolution and hand tally are idempotent.

## 13. Test cases
1. First trick: only the 2♣ holder can act, and only with the 2♣.
2. Follow-suit enforcement: holding the led suit blocks off-suit plays.
3. Hearts cannot lead before broken (unless hand is all hearts).
4. No points playable on trick 1 when a safe card exists.
5. Trick winner = highest of led suit; winner leads next.
6. Pass rotation order left → right → across → hold, then repeats.
7. Moon shot: 26-point hand → shooter +0, others +26.
8. Match ends when a total ≥ 100; lowest total wins.
9. All-AI game completes 13 tricks × N hands with no stuck phase.
10. Pause/resume mid-trick continues correctly; watchdog never double-counts.
