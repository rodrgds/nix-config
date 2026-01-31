#!/usr/bin/env bash

question=$(rofi -dmenu -p "Ask a question:")

if [ -z "$question" ]; then
  exit 1
else
  answer=$(ollama run mistral-openorca "Answer the following question using simple terms, synthetically and DON'T repeat my question on your answer. Just answer straight away and straight to the point.\n$question")
  # Answer the following question using simple terms, synthetically and DON'T repeat my question on your answer. Just answer straight away and straight to the point.
  # Answer concisely and get straight to the point. No introductions needed. If the answer doesn't require an explanation, don't give me one. Also, don't answer with the first thing that comes to mind, think about what you are going to answer and MAKE SURE to answer correctly. Listen precisely to my request and answer it in the best way possible, looking at every single detail in my request and making sure to fulfill it.
  zenity --info --text="$answer" --title="Answer: $question"
fi
