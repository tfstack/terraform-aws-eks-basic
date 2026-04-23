"use strict";

// Cognito SAML maps Entra groups into custom:groups (see attribute_mapping in headlamp.tf).
// GROUP_RULES comes from Lambda env (Terraform jsonencode of headlamp_rbac_group_rules).
var GROUP_RULES = JSON.parse(process.env.GROUP_RULES || "[]");

function normalizeGroupList(raw) {
  if (raw == null || raw === "") return [];
  if (typeof raw !== "string") return [];
  return raw
    .replace(/\r?\n/g, ",")
    .split(",")
    .map(function (s) {
      return s.trim();
    })
    .filter(Boolean);
}

function resolveK8sGroupsFromDirectoryGroups(groupNames) {
  var out = [];
  var seen = new Set();
  for (var i = 0; i < GROUP_RULES.length; i++) {
    var dir = GROUP_RULES[i].directory_group;
    var k8s = GROUP_RULES[i].k8s_group;
    if (groupNames.indexOf(dir) !== -1 && k8s && !seen.has(k8s)) {
      seen.add(k8s);
      out.push(k8s);
    }
  }
  return out;
}

function allowedK8sFromRules() {
  var s = new Set();
  for (var i = 0; i < GROUP_RULES.length; i++) {
    if (GROUP_RULES[i].k8s_group) s.add(GROUP_RULES[i].k8s_group);
  }
  return s;
}

exports.handler = async function (event) {
  var req = event.request || {};
  var attrs = req.userAttributes || {};
  var rawDirectory = attrs["custom:groups"];
  var directoryGroups = normalizeGroupList(rawDirectory);
  var poolGroups = (req.groupConfiguration && req.groupConfiguration.groupsToOverride) || [];

  var k8sGroups = resolveK8sGroupsFromDirectoryGroups(directoryGroups);
  if (k8sGroups.length === 0) {
    var allowed = allowedK8sFromRules();
    k8sGroups = poolGroups.filter(function (g) {
      return allowed.has(g);
    });
  }

  console.log(
    JSON.stringify({
      msg: "headlamp-pre-token: request",
      triggerSource: event.triggerSource,
      userName: event.userName,
      userPoolId: event.userPoolId,
      customGroupsRaw: rawDirectory != null ? rawDirectory : null,
      directoryGroupsParsed: directoryGroups,
      poolGroupsToOverride: poolGroups,
      userAttributeKeys: Object.keys(attrs),
    })
  );

  if (k8sGroups.length === 0) {
    throw new Error("Access denied: user is not in any authorised group");
  }

  console.log(
    JSON.stringify({
      msg: "headlamp-pre-token: response",
      groupsToOverride: k8sGroups,
    })
  );

  event.response = {
    claimsAndScopeOverrideDetails: {
      groupOverrideDetails: {
        groupsToOverride: k8sGroups,
        iamRolesToOverride: [],
      },
    },
  };
  return event;
};
