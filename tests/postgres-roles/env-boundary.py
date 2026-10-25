#!/usr/bin/env python3
"""Assert grants at evaluated OCI/template boundaries, no real secrets consumed.

Usage: env-boundary.py AFTER.json BEFORE.json
The role fixture owns the SQL security contract. This separate test protects
credential delivery and reconnect ordering, which SQL alone cannot observe.
"""
import json
import sys
from pathlib import Path


def check(config, before):
    for service in ["montra", "openpost", "umami", "shlink"]:
        secret = service + "_postgres_admin_password"
        assert secret in config["placeholders"], service + ": separate admin credential missing"
        marker = config["placeholders"][secret]
        admin_templates = {name for name, template in config["templates"].items() if marker in template["content"]}
        expected = service + ("-postgres-env" if service in ["montra", "openpost"] else "-postgres-admin-password")
        assert admin_templates == {expected}, service + ": admin credential grant escaped PostgreSQL"
        path = config["templates"][expected]["path"]
        db = config["containers"][service + "-postgres"]
        assert path in db["environmentFiles"] or any("source=" + path + "," in option for option in db["extraOptions"])
        for name, container in config["containers"].items():
            if name == service + "-postgres":
                continue
            assert marker not in json.dumps(container), name + ": inline admin credential"
            assert path not in container["environmentFiles"], name + ": admin environment grant"
            assert not any("source=" + path + "," in option for option in container["extraOptions"]), name + ": admin mount grant"
        # Runtime app credentials and template contents are byte-identical to
        # baseline. Only PG's bootstrap environment and the new admin grant differ.
        for name, template in before["templates"].items():
            if name.startswith(service) and name != service + "-postgres-env":
                assert config["templates"][name]["content"] == template["content"], name + ": existing app secret content changed"
        runtime = ["podman-montra-api", "podman-montra-worker", "podman-montra-integration-worker"] if service == "montra" else ["podman-" + service]
        if service == "openpost":
            runtime.append("podman-openpost-worker")
        init = {"montra": "montra-initialize", "openpost": "openpost-postgres-credential-reconcile"}.get(service, service + "-postgres-roles")
        for unit in runtime:
            assert unit + ".service" in config["templates"][expected]["restartUnits"], unit + ": admin rotation can leave runtime stopped after PG restart"
            assert config["units"][unit]["restartTriggers"], unit + ": first transition does not force reconnect"
            assert init + ".service" in config["units"][unit]["requires"] or unit + ".service" in config["units"][init]["requiredBy"], unit + ": role initializer is not required"
    for name, template in config["templates"].items():
        assert template["mode"] == "0400", name + ": secret template is not root-only"
    print("PASS: evaluated admin-only PG grants, unchanged runtime app templates, private mounts, required init and reconnect triggers")


if __name__ == "__main__":
    check(json.loads(Path(sys.argv[1]).read_text()), json.loads(Path(sys.argv[2]).read_text()))
