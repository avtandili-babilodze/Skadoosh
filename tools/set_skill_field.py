"""Sets one field of a skill inside a hero.tres, found by the skill's name.

    python tools/set_skill_field.py <hero folder> "<skill name>" <field> <value>

The value is written as-is (quote strings yourself: '"fireball"').
"""
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")


def set_field(hero, skill, field, value):
    path = os.path.join(ROOT, "data", "heroes", hero, "hero.tres")
    text = open(path, encoding="utf-8").read()
    blocks = list(re.finditer(r'\[sub_resource[^\]]*\]\n(?:(?!\n\[).)*', text, re.S))
    for block in blocks:
        body = block.group(0)
        if 'skill_name = "%s"' % skill not in body:
            continue
        line = re.compile(r'^%s = .*$' % re.escape(field), re.M)
        if line.search(body):
            new_body = line.sub("%s = %s" % (field, value), body)
        else:
            new_body = body.rstrip("\n") + "\n%s = %s" % (field, value)
        text = text[:block.start()] + new_body + text[block.end():]
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        return True
    raise SystemExit("skill %r not found in %s" % (skill, path))


if __name__ == "__main__":
    set_field(*sys.argv[1:5])
    print("set", sys.argv[3], "=", sys.argv[4], "on", sys.argv[2])
