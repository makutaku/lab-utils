#!/usr/bin/env python3
"""
apply_switch_config.py

This script applies a RouterOS switch configuration from a YAML file. It:
  1. Connects to a RouterOS device via its API.
  2. Configures bridge ports based on a list of interface configuration strings.
  3. Builds an inverted map of VLAN IDs to untagged interfaces.
  4. Updates (or creates) /interface bridge vlan entries so that interfaces
     appear only in the untagged list (removing them from tagged, if necessary).

Usage:
    python apply_switch_config.py --config switch1.yaml --loglevel DEBUG
"""

import argparse
import logging
import sys
import yaml
import routeros_api


def parse_config(config_str):
    """
    Parse a configuration string of the format:
      "iface,pvid,ingress_filter,frame_types"
    Returns a tuple: (iface, pvid, ingress_filter, frame_types)
    """
    parts = config_str.split(',')
    if len(parts) != 4:
        raise ValueError(f"Invalid config string format: {config_str}")
    return parts[0], parts[1], parts[2], parts[3]


def array_to_string(arr):
    """Join a list of strings with commas."""
    return ",".join(arr)


def get_id(resource_entry, resource_name):
    """
    Attempt to get the resource ID from a dictionary returned by the API.
    Try '.id' first; if not present, try 'id'. Log an error if none found.
    """
    rid = resource_entry.get('.id')
    if not rid:
        rid = resource_entry.get('id')
    if not rid:
        logging.error(f"Could not find ID for {resource_name}. Entry: {resource_entry}")
    return rid


def apply_switch_config(device_cfg):
    """
    Connect to a switch using device_cfg, apply interface settings,
    build an inverted VLAN map, and update /interface bridge vlan entries.
    """
    host = device_cfg["host"]
    port = device_cfg["port"]
    username = device_cfg["username"]
    password = device_cfg["password"]
    use_ssl = device_cfg.get("use_ssl", False)
    ssl_verify = device_cfg.get("ssl_verify", False)
    bridge_name = device_cfg["bridge_name"]
    interface_configs = device_cfg["interface_configs"]

    logger = logging.getLogger(__name__)
    logger.info(f"Connecting to {device_cfg.get('name', host)} at {host}:{port} ...")

    try:
        connection = routeros_api.RouterOsApiPool(
            host=host,
            username=username,
            password=password,
            port=port,
            use_ssl=use_ssl,
            ssl_verify=ssl_verify,
            plaintext_login=True
        )
        api = connection.get_api()
    except Exception as ex:
        logger.error(f"Error connecting to device {host}: {ex}")
        return

    bridge_port_res = api.get_resource('/interface/bridge/port')
    vlan_res = api.get_resource('/interface/bridge/vlan')

    # Build an inverted map: VLAN ID -> list of untagged interfaces
    vlan_map = {}

    logger.info("Processing interface configurations...")
    for cfg_str in interface_configs:
        try:
            iface, pvid, ingress_filter, frame_types = parse_config(cfg_str)
        except ValueError as ve:
            logger.error(ve)
            continue

        logger.debug(f"Parsed config: iface={iface}, pvid={pvid}, "
                     f"ingress_filter={ingress_filter}, frame_types={frame_types}")

        # Add or update the bridge port for this interface
        try:
            existing = bridge_port_res.get(interface=iface, bridge=bridge_name)
            if existing:
                port_id = get_id(existing[0], f"bridge port {iface}")
                if not port_id:
                    continue
                bridge_port_res.set(
                    id=port_id,
                    pvid=pvid,
                    **{'frame-types': frame_types},
                    **{'ingress-filtering': ingress_filter}
                )
                logger.info(f"Updated bridge port for interface '{iface}'.")
            else:
                bridge_port_res.add(
                    bridge=bridge_name,
                    interface=iface,
                    pvid=pvid,
                    **{'frame-types': frame_types},
                    **{'ingress-filtering': ingress_filter}
                )
                logger.info(f"Added bridge port for interface '{iface}'.")
        except Exception as ex:
            logger.error(f"Error processing interface '{iface}': {ex}")

        # Update VLAN map (using pvid as VLAN ID)
        vlan_map.setdefault(pvid, []).append(iface)

    logger.info("Inverted VLAN Map (untagged):")
    for vlan_id, ifaces in vlan_map.items():
        logger.info(f"  VLAN {vlan_id}: {','.join(ifaces)}")

    # Update or create VLAN entries on the device
    for vlan_id, untagged_list in vlan_map.items():
        untagged_str = array_to_string(untagged_list)
        try:
            existing_vlans = vlan_res.get(
                bridge=bridge_name,
                **{'vlan-ids': vlan_id}
            )
        except Exception as ex:
            logger.error(f"Error retrieving VLAN {vlan_id} info: {ex}")
            continue

        if existing_vlans:
            vlan_entry_id = get_id(existing_vlans[0], f"VLAN {vlan_id}")
            if not vlan_entry_id:
                continue
            current_tagged = existing_vlans[0].get('tagged', '')
            logger.info(f"Found VLAN entry for VLAN {vlan_id} (ID: {vlan_entry_id}).")
            logger.debug(f"  Current tagged: {current_tagged}")

            # Convert current tagged list into an array (assuming comma-separated)
            tagged_array = current_tagged.split(',') if current_tagged.strip() else []
            # Remove any interfaces that are in the untagged list
            new_tagged_array = [t for t in tagged_array if t not in untagged_list]
            final_tagged_str = array_to_string(new_tagged_array)
            try:
                vlan_res.set(
                    id=vlan_entry_id,
                    untagged=untagged_str,
                    tagged=final_tagged_str
                )
                logger.info(f"Updated VLAN {vlan_id}: untagged={untagged_str}, tagged={final_tagged_str}")
            except Exception as ex:
                logger.error(f"Error updating VLAN {vlan_id} entry: {ex}")
        else:
            try:
                vlan_res.add(
                    bridge=bridge_name,
                    **{'vlan-ids': vlan_id},
                    untagged=untagged_str
                )
                logger.info(f"Created VLAN {vlan_id} with untagged={untagged_str}")
            except Exception as ex:
                logger.error(f"Error creating VLAN {vlan_id} entry: {ex}")

    connection.disconnect()
    logger.info("Disconnected from device.")


def main():
    parser = argparse.ArgumentParser(
        description="Apply RouterOS switch configuration from a YAML file."
    )
    parser.add_argument(
        "--config",
        required=True,
        help="Path to the YAML configuration file for the switch."
    )
    parser.add_argument(
        "--loglevel",
        default="INFO",
        choices=["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"],
        help="Logging level (default: INFO)."
    )
    args = parser.parse_args()

    # Configure logging
    numeric_level = getattr(logging, args.loglevel.upper(), logging.INFO)
    logging.basicConfig(
        level=numeric_level,
        format='%(asctime)s [%(levelname)s] %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    logger = logging.getLogger(__name__)
    logger.debug("Logger initialized at level " + args.loglevel.upper())

    # Read the YAML configuration file for the switch
    try:
        with open(args.config, 'r') as f:
            device_cfg = yaml.safe_load(f)
    except Exception as ex:
        logger.error(f"Failed to read configuration file '{args.config}': {ex}")
        sys.exit(1)

    apply_switch_config(device_cfg)


if __name__ == '__main__':
    main()
