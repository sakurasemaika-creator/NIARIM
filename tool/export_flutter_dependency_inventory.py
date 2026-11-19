#!/usr/bin/env python3
"""Export the resolved Dart dependency graph and package license evidence."""

import argparse
import hashlib
import json
from pathlib import Path
from urllib.parse import unquote, urlparse


def write_json(destination, data):
    destination.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def package_directory(entry, config_path):
    uri = urlparse(entry["rootUri"])
    if uri.scheme == "file":
        return Path(unquote(uri.path))
    if not uri.scheme:
        return config_path.parent / unquote(uri.path)
    raise ValueError(f"Unsupported package source for {entry['name']}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dependency_graph", type=Path)
    parser.add_argument("package_config", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    graph = json.loads(args.dependency_graph.read_text(encoding="utf-8"))
    config = json.loads(args.package_config.read_text(encoding="utf-8"))
    packages = {package["name"]: package for package in graph["packages"]}
    root = graph["root"]
    if root not in packages or len(packages) < 2:
        raise ValueError("The resolved dependency graph is empty or missing the application")
    directories = {
        entry["name"]: package_directory(entry, args.package_config)
        for entry in config["packages"]
    }
    references = {name: f"{name}@{package['version']}" for name, package in packages.items()}

    args.output.mkdir(parents=True, exist_ok=True)
    components = []
    dependencies = []
    license_evidence = []
    for name, package in sorted(packages.items()):
        reference = references[name]
        component = {
            "type": "application" if name == root else "library",
            "name": name,
            "version": package["version"],
            "bom-ref": reference,
        }
        if name != root:
            components.append(component)
        else:
            application = component
        dependencies.append({
            "ref": reference,
            "dependsOn": sorted(references[item] for item in package["dependencies"]),
        })

        if name == root:
            continue
        directory = directories[name]
        text_files = []
        for path in sorted(directory.iterdir()):
            filename = path.name.lower()
            if not path.is_file() or filename.split(".")[0] not in {
                "license", "licence", "copying", "notice",
            }:
                continue
            contents = path.read_bytes()
            evidence_path = Path("license-texts") / name / path.name
            destination = args.output / evidence_path
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(contents)
            text_files.append({
                "path": evidence_path.as_posix(),
                "sha256": hashlib.sha256(contents).hexdigest(),
            })
        license_evidence.append({
            "name": name,
            "version": package["version"],
            "source": package["source"],
            "status": "text-found" if text_files else "needs-review",
            "files": text_files,
        })

    write_json(args.output / "flutter.cdx.json", {
        "$schema": "http://cyclonedx.org/schema/bom-1.5.schema.json",
        "bomFormat": "CycloneDX",
        "specVersion": "1.5",
        "version": 1,
        "metadata": {"component": application},
        "components": components,
        "dependencies": dependencies,
    })
    write_json(args.output / "flutter-license-evidence.json", license_evidence)
    missing = sum(entry["status"] == "needs-review" for entry in license_evidence)
    print(f"Flutter packages: {len(components)}, without license/notice text: {missing}")


if __name__ == "__main__":
    main()
