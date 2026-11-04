"""Run one of upstream's tasks/schema scripts without the tasks package.

Usage, from the agent checkout: run-schema-tool.py <script.py> [args...]

tasks/__init__.py imports invoke and the rest of upstream's task tree, so the
tasks and tasks.schema packages are replaced by empty packages that keep only
their paths. The scripts then import their sibling modules from the checkout.
"""
import runpy
import sys
import types

tasks = types.ModuleType("tasks")
tasks.__path__ = ["tasks"]
schema = types.ModuleType("tasks.schema")
schema.__path__ = ["tasks/schema"]
tasks.schema = schema
sys.modules.update({"tasks": tasks, "tasks.schema": schema})

script = sys.argv[1]
sys.argv = sys.argv[1:]
runpy.run_path(script, run_name="__main__")
