import os
import sys

args = sys.argv[1:] or ["python3"]
os.execvp(args[0], args)
