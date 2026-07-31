#!/usr/bin/env python3

from PIL import ImageGrab
import io
import base64
import pyperclip
import requests
import json
import os
from pathlib import Path

def get_openai_api_key():
  """Read OpenAI API key from sops-decrypted secret file."""
  # sops-nix places secrets in the runtime directory
  runtime_dir = Path(os.environ.get('XDG_RUNTIME_DIR', f"/run/user/{os.getuid()}"))
  api_key_file = runtime_dir / "openai_api_key"
  
  if api_key_file.exists():
    return api_key_file.read_text().strip()
  else:
    raise FileNotFoundError(f"OpenAI API key not found at {api_key_file}. Make sure sops-nix is configured correctly.")

def get_clipboard_image():
  img = ImageGrab.grabclipboard()
  if img is None:
      return None
  buffer = io.BytesIO()
  img.save(buffer, format="PNG")
  return base64.b64encode(buffer.getvalue()).decode('utf-8')

def get_caption(image_base64):
  api_key = get_openai_api_key()
  headers = {
    "Content-Type": "application/json",
    "Authorization": f"Bearer {api_key}"
  }
  payload = {
    "model": "gpt-4o",
    "messages": [
      {
        "role": "user",
        "content": [
          {"type": "text", "text": """
<instructions>
  You are a professional Twitter/X replier and software engineer. Your task is to write the best possible comment to the following post, that yields the highest number of likes and that is in no way, shape or form cringe. The post is attached as an image.

  You may take the following posts and great replies as examples on how to craft your reply. Try to get the essence of how these are such good replies and apply it to the reply you'll write to the post above. Don't be cringe. Don't just rephrase the post, add to it or be funny! I repeat: don't be cringe. You may talk personally (as if you were me), and talk about personal experiences if you find helpful. Don't be afraid to suggest specific tools or of giving out actually good information! Understand if the post contains sarcasm. You may also use sarcasm in your reply if you find it will drive engagement or make the reply better or funnier. Reply with ONLY the reply you'd write to the post above - nothing more. LEARN FROM THE EXAMPLES BELOW!
</instructions>

<example-posts>

<example>
  <post>
    I keep coming across all these "pseudocode" examples on Wikipedia and in academic papers, and what I don't understand is why the authors can't just learn a real programming language
  </post>
  <reply>
    Assuming you're not joking, the point is to be independent of implementation and focus on the theory. It's kinda like why we say theoretically two plus two is four, not two things plus two things is four things.
  </reply>
  <reply>
    sometimes it lets them hide the fact that the algorithm doesn't actually work
  </reply>
  <reply>
    Because I'm sure you realized there is quite a bit of handwaving going on. They are not interested in writing code, much less code that works. They just want a more concise notation that is not English which is too verbose. Code is secondary for their paper which is their main focus. They want to express the algorithm sufficiently to get the paper done. Turning it into actual code does not add more value to the paper so it's not worth their time
  </reply>
</example>

<example>
  <post>
    Just Googled something instead of using AI.

    Absolutely awful experience.

    Internet search is deprecated.
  </post>
  <reply>
    I still Google... All the time. What did you find frustrating? Whenever I try to use AI it just makes stuff up, even today!
  </reply>
</example>

<example>
  <post>
    insane how there's no actual github competitors
  </post>
  <reply>
    GitHub is a social network that happens to host code
  </reply>
</example>

<example>
  <post>
    You need to make $10k.

    In the next 14 days.

    How are you doing it?
  </post>
  <reply>
    1. Get a list of leads that match your target audience, buy them or scrape them.
    2. Set up an outbound system with Zapier/Make.com, and Instantly to send 1,000 's of AI personalized emails with strong copy.
    3. Close 6-7 deals at $1.5K-$2K each.

    Repeat the process. Let's connect if you want help setting this up!
  </reply>
  <reply>
    Why would I be scrolling on twitter if I know how to do so? 🤔😂
  </reply>
  <reply>
    1. Find list of companies with funding/revenue but ugly platform/web app
    2. Contact them like crazy with my portfolio
    3. Close 1 deal and implement facelift in a week
  </reply>
</example>

<example>
  <post>
    Me👨 and Cursor 🤖:

    👨: <Pasting an error message>
    👨: Can you fix that?
    🤖: Ok.
    🤖: <code still broken> 
    👨: Doesn't work
    👨: Doesn't work
    👨: Doesn't work
    👨: Doesn't work
  </post>
  <reply>
    this is closer to reality than:
    "I build this MVP in 3 days without coding, just using cursor prompting, here are my 10 tips:"
  </reply>
  <reply>
    👨: Can you fix that? 
    🤖: Ok (Proceeds to introduce more bugs).
  </reply>
</example>

<example>
  <post>
    Does anybody else hate Jira? Please recommend me an alternative solution because it's driving me crazy.
  </post>
  <reply>
    Frankly, I haven't found a single one! It's crazy.

    I've used Jira, Monday, Pivotal Tracker, Trello, Asana

    Maybe Trello is the closest to actually useful for getting shit done, but last I used it it didn't have much in the way of reporting. So, if reporting is important, then /shrug
  </reply>
</example>

<example>
  <post>
    How can you stand out as a software engineer?

    Learn the skills that others avoid:

    • Learn unit testing.
    • Learn CI/CD pipelines.
    • Learn automation tools.
    • Learn performance tuning.
    • Learn security best practices.
    • Learn effective branching strategies.
    • Learn cloud infrastructure management.

    Most fall short here.
  </post>
  <reply>
    To stand out in quality companies you have to be an expert in all, not just one
  </reply>
</example>

<example>
  <post>
    AI is creating a generation of illiterate programmers. That's for sure.
  </post>
  <reply>
    But a generation of deeper learners as well. "Teach me" people will go further than "do it for me" people
  </reply>
</example>

<example>
  <post>
    Experienced devs who are 30+, please drop one piece of advice for devs 18 to 29. It can be about anything!
  </post>
  <reply>
    Spend a small amount of time each week reading books and papers. Spending an hour or two a week can put you far ahead of your peers especially when done consistently.
    Blog posts can be useful but are generally low quality so focus on papers and books.
  </reply>
</example>

</example-posts>
"""},
          {"type": "image_url", "image_url": {"url": f"data:image/png;base64,{image_base64}"}}
        ]
      }
    ]
  }
  response = requests.post("https://api.openai.com/v1/chat/completions", headers=headers, json=payload)
  return json.loads(response.text)['choices'][0]['message']['content']

# Main script
image_base64 = get_clipboard_image()
if image_base64:
  caption = get_caption(image_base64)
  pyperclip.copy(caption)
  print("Caption generated and copied to clipboard:", caption)
else:
  print("No image found in clipboard.")
