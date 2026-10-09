# Thompson Construction Engine

A cross-platform Flutter application that constructs equivalent ε-NFA graphs from regular expressions using Thompson’s Construction.

## Introduction
Thompson Construction Engine is an educational application designed to demonstrate how regular expressions are converted into equivalent Epsilon-Nondeterministic Finite Automata (ε-NFA).

## Problem Statement
To develop a compiler front-end that accepts basic regular expressions and mathematically constructs their equivalent ε-NFA graph using Thompson’s Construction algorithm.

## Objectives
- Accept and validate regular expressions.
- Support union, concatenation, Kleene star, and parentheses.
- Convert infix regular expressions into postfix notation.
- Construct the equivalent ε-NFA.
- Display states and transitions graphically.
- Show the transition table and construction steps.
- Identify invalid regular expressions.

## Features
- Interactive ε-NFA graph.
- Start and final state indicators.
- Epsilon (ε) transitions.
- Transition table.
- Step-by-step construction details.
- Graph zooming and panning.
- Input validation with error messages.
- Android and Windows desktop support.

## Supported Operators

| Symbol | Operation | Example |
|---|---|---|
| `.` | Concatenation | `a.b` |
| `|` | Union | `a|b` |
| `*` | Kleene Star | `a*` |
| `()` | Grouping | `(a|b)` |

## Example

**Input regular expression:**

`((a|b)*.c)|(d.e)`

This expression demonstrates union, Kleene star, concatenation, and grouping. The application constructs and displays its equivalent ε-NFA.

## Invalid Input Examples

- `a|` — missing expression after union.
- `(a|b` — unmatched opening parenthesis.
- `*` — invalid placement of the Kleene star.

## Technologies Used
- Flutter
- Dart
- Thompson’s Construction Algorithm
- Finite Automata and Regular Expressions

## Platforms
- Android
- Windows Desktop

## Purpose
This project demonstrates the mathematical construction of ε-NFAs from regular expressions and helps students understand concepts from Theory of Computation.

## Author
**Sudhanshu Kalidas Gedam**

**USN:** CM24051

**Program:** B.Tech CSE (Artificial Intelligence and Machine Learning)
