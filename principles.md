# Design principles

## 1. Extensibility

The supreme design metric. A good core is small and solid enough that extensions are built on top of it cheaply, whether or not anyone builds them. This is not generality as features: a core that does many things is not the goal; a core that many things can be built on is.

Reference: Parnas, *Designing Software for Ease of Extension and Contraction* (1979).

## 2. Local reasoning, modularity, and encapsulation

A function can be understood from its body, its arguments and the shapes of its data. Nobody can build on a core they cannot reason about locally.
The same holds for files, modules, and libraries.


## 3. Honest calls

A function does what its name says, and nothing runs inside it that the caller did not ask for. Changing data is boring: it writes data and nothing else.

One technique: **separate deciding from doing.**  Each half can be understood alone, and failing is simple, because deciding changed nothing.

## 4. Explicit time

Consequences happen at named points, such as the end of a command or the end of a tick. The order of those points is written in one place, the outer loop, not spread across callbacks. Modules are split by what they are about, not by when they run (Ousterhout's "temporal decomposition" is the failure).

## 5. Data is the whole truth

Every fact has one home, in plain data. Everything else is derived: computed, or held in a cache that could be thrown away.

## 6. Make misuse impossible

Prefer shapes that cannot express the wrong thing over checks that catch it at runtime ("parse, don't validate"). Then the rulebook a user must know stays small. 

## 7. Promise little

Promises are what make code worth building on: a pure function and an honest call are promises. An interface promises what its users need, plainly, and nothing they cannot use or could take two ways. The trouble starts when we lose track of what we are actually trying to do; it shows as complex interfaces and messy contracts, and the cleverest code is usually keeping a promise nobody asked for. When a design grows complex, the first move is to go back to the need and ask which promises it asks for, not to improve the mechanism that keeps the rest.

## 8. Decisions live where the knowledge is

A mechanism never makes a decision that belongs to its caller, the game, or the player. What it cannot decide well, it returns, or leaves to the layer that knows both sides. 



