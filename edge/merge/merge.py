#!/usr/bin/env python
# prototype for https://review.opendev.org/#/c/664065
# -------------------------------------------------------
# An ansible inventory host group will be created for every
# item in the cross product of stacks and roles. For example,
# central-controllers, edge0-computes, edge1-computes, etc.
#
# for stack in stacks:
#     for role in stack.roles:
#         print stack +"-"+ role
#         for host in role.hosts:
#             print host
# -------------------------------------------------------
import json

stacks = ["central", "edge0", "edge1", "edge2"]

for stack in stacks:
    with open(stack+".json") as file:
        inv = json.load(file)
        print(stack + " -->")
        print(json.dumps(inv, indent=2))
