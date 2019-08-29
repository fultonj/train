#!/usr/bin/env python3
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
from collections import OrderedDict

def merge(stacks):
    ret = OrderedDict()
    for stack in stacks:
        with open(stack+".json") as file:
            inv = json.load(file)
            #print(stack + " -->")
            #print(json.dumps(inv, indent=2))

            # only want one undercloud, shouldn't matter which
            if 'Undercloud' not in ret.keys():
                ret['Undercloud'] = inv['Undercloud']
                # add 'plans' to create a list to append to
                ret['Undercloud']['vars']['plans'] = []

            # save the plan for this stack in the plans list
            plan = inv['Undercloud']['vars']['plan']
            ret['Undercloud']['vars']['plans'].append(plan)

            for key in inv.keys():
                if key != 'Undercloud':
                    new_key = stack + '_' + key
                    if 'children' in inv[key].keys():
                        roles = []
                        for child in inv[key]['children']:
                            roles.append(stack + '_' + child)
                        ret[new_key] = {}
                        ret[new_key]['children'] = roles
                        ret[new_key]['vars'] = inv[key]['vars']
                        if key == 'overcloud':
                            # useful to have just stack name refer to children
                            ret[stack] = {}
                            ret[stack]['children'] = roles
                            ret[stack]['vars'] = inv[key]['vars']
                    else:
                        ret[new_key] = inv[key]

    # 'plan' doesn't make sense when using multiple plans
    ret['Undercloud']['vars']['plan'] = None
    return ret

if __name__ == '__main__':
    stacks = ["central", "edge0", "edge1", "edge2"]
    inventory = merge(stacks)
    print(json.dumps(inventory, indent=2))
