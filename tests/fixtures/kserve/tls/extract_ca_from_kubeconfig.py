#!/usr/bin/env python3
"""Extract CA bundle from a kubeconfig cluster entry.

Usage:
  extract_ca_from_kubeconfig.py --list <kubeconfig>
  extract_ca_from_kubeconfig.py <kubeconfig> [cluster-name] --out-dir <dir>
"""

from __future__ import annotations

import argparse
import base64
import sys
from pathlib import Path

import yaml


def load_kubeconfig(path: Path) -> dict:
    with path.open() as handle:
        return yaml.safe_load(handle)


def list_clusters(kubeconfig_path: Path) -> int:
    kc = load_kubeconfig(kubeconfig_path)
    print(f"Clusters in {kubeconfig_path}:")
    for cluster in kc["clusters"]:
        server = cluster["cluster"].get("server", "(unknown)")
        has_ca = "yes" if cluster["cluster"].get("certificate-authority-data") else "no"
        print(f"  {cluster['name']}  server={server}  ca-data={has_ca}")
    return 0


def resolve_cluster(kc: dict, cluster_name: str | None) -> tuple[str, dict]:
    if not cluster_name:
        target = kc["clusters"][0]
        name = target["name"]
        print(f"No cluster name given, using first entry: {name}")
        return name, target

    for cluster in kc["clusters"]:
        if cluster["name"] == cluster_name:
            return cluster_name, cluster

    print(f"Error: cluster '{cluster_name}' not found in kubeconfig", file=sys.stderr)
    print("Available clusters:", file=sys.stderr)
    for cluster in kc["clusters"]:
        print(f"  - {cluster['name']}", file=sys.stderr)
    sys.exit(1)


def extract_ca(kubeconfig_path: Path, cluster_name: str | None, out_dir: Path) -> int:
    kc = load_kubeconfig(kubeconfig_path)
    name, target = resolve_cluster(kc, cluster_name)

    ca_b64 = target["cluster"].get("certificate-authority-data")
    if not ca_b64:
        print(
            f"Error: cluster '{name}' has no certificate-authority-data",
            file=sys.stderr,
        )
        return 1

    pem = base64.b64decode(ca_b64).decode("utf-8")
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "ca-bundle.pem").write_text(pem)
    (out_dir / "ca-data-base64.txt").write_text(ca_b64)

    count = pem.count("BEGIN CERTIFICATE")
    server = target["cluster"].get("server", "(unknown)")
    print(f"Extracted {count} CA certificates for cluster {name} ({server})")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--list",
        action="store_true",
        help="List clusters in the kubeconfig and exit",
    )
    parser.add_argument("kubeconfig", type=Path, help="Path to kubeconfig")
    parser.add_argument(
        "cluster_name",
        nargs="?",
        default=None,
        help="Cluster entry name (default: first entry)",
    )
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=Path(__file__).resolve().parent,
        help="Directory for ca-bundle.pem and ca-data-base64.txt",
    )
    args = parser.parse_args()

    if not args.kubeconfig.is_file():
        print(f"Error: kubeconfig not found at {args.kubeconfig}", file=sys.stderr)
        return 1

    if args.list:
        return list_clusters(args.kubeconfig.resolve())

    return extract_ca(
        args.kubeconfig.resolve(),
        args.cluster_name,
        args.out_dir.resolve(),
    )


if __name__ == "__main__":
    sys.exit(main())
