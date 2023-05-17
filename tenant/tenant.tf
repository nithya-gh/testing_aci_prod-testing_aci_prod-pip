terraform {
  required_providers {
    aci = {
      source = "ciscodevnet/aci"
    }
  }
}



# CREATE TENANT

resource "aci_tenant" "test_cups_tenant" {
  for_each = var.tenant_id
  name     = each.value.tnt_name
}

# CREATE VRF

resource "aci_vrf" "test_cups_vrf" {
  for_each               = var.vrf_id
  tenant_dn              = aci_tenant.test_cups_tenant[each.value.tnt_name].id
  name                   = each.value.vrf_name
  bd_enforced_enable     = "yes"
  ip_data_plane_learning = "enabled"
  knw_mcast_act          = "permit"
  pc_enf_pref            = "unenforced"
}


# CREATE BRIDGE DOMAIN

resource "aci_bridge_domain" "test_cups_bd" {
  for_each           = var.bridge_domains
  tenant_dn          = aci_tenant.test_cups_tenant[each.value.tnt_name].id
  relation_fv_rs_ctx = aci_vrf.test_cups_vrf[each.value.vrf_name].id
  name               = each.value.name
  arp_flood          = each.value.arp_flood
  ip_learning        = each.value.ip_learning
  unicast_route      = each.value.unicast_route
}


# CREATE BRIDGE DOMAIN - SUBNET

resource "aci_subnet" "test_cups_bd_subnets" {
  for_each = { for k in compact([for k, v in var.bridge_domains : v.subnetpresent ? k : ""]) : k => var.bridge_domains[k] }
  #  for_each  = var.bridge_domains
  parent_dn = aci_bridge_domain.test_cups_bd[each.key].id
  ip        = each.value.subnet
  scope     = ["${each.value.subnet_scope}"]
}


# CREATE APPLICATION PROFILE

resource "aci_application_profile" "test_cups_ap" {
  for_each  = var.app_prof
  tenant_dn = aci_tenant.test_cups_tenant[each.value.tnt_name].id
  name      = each.value.name
}


# CREATE CONTRACT

resource "aci_contract" "test_cups_con" {
  tenant_dn = aci_tenant.test_cups_tenant["demoapr6"].id
  name      = "CON_PASS_ALL"
}

resource "aci_contract_subject" "test_cups_sub" {
  contract_dn                  = aci_contract.test_cups_con.id
  name                         = "SUB_PASS_ALL"
  relation_vz_rs_subj_filt_att = [aci_filter.allow_icmp.id]
}

resource "aci_filter" "allow_icmp" {
  tenant_dn = aci_tenant.test_cups_tenant["demoapr6"].id
  name      = "allow_icmp"
}

resource "aci_filter_entry" "icmp" {
  name      = "icmp"
  filter_dn = aci_filter.allow_icmp.id
  ether_t   = "ip"
  prot      = "icmp"
  stateful  = "yes"
}


# USE THE EXISTING DOMAIN

data "aci_physical_domain" "phy_dom_1" {
  name = "PHY_DOM_DEMO"
}


# CREATE EPG

resource "aci_application_epg" "test_cups_epg" {
  for_each               = var.end_point_groups
  application_profile_dn = aci_application_profile.test_cups_ap[each.value.ap_name].id
  name                   = each.value.name
  relation_fv_rs_bd      = aci_bridge_domain.test_cups_bd[each.value.bd].id
  relation_fv_rs_cons    = [aci_contract.test_cups_con.id]
  relation_fv_rs_prov    = [aci_contract.test_cups_con.id]
}

# ASSOCIATING EPG TO DOMAIN

resource "aci_epg_to_domain" "test_cups_epg_to_domain" {
  for_each           = var.end_point_groups
  application_epg_dn = aci_application_epg.test_cups_epg[each.key].id
  tdn                = data.aci_physical_domain.phy_dom_1.id
}


# ADDING STATIC PATH TO THE EPG

resource "aci_epg_to_static_path" "test_cups_epg_to_static_path_access" {
  for_each = { for k in compact([for k, v in var.epg_static_bind : v.access ? k : ""]) : k => var.epg_static_bind[k] }
  #for_each           = var.epg_static_bind
  application_epg_dn = aci_application_epg.test_cups_epg[each.value.epg_name].id
  tdn                = "topology/pod-1/paths-${each.value.leaf_id}/pathep-[${each.value.intf_id}]"
  encap              = each.value.vlan_encap
  mode               = each.value.trunk_mode
}

resource "aci_epg_to_static_path" "test_cups_epg_to_static_path_pc" {
  for_each = { for k in compact([for k, v in var.epg_static_bind : v.access ? "" : k]) : k => var.epg_static_bind[k] }
  #for_each           = var.epg_static_bind
  application_epg_dn = aci_application_epg.test_cups_epg[each.value.epg_name].id
  tdn                = "topology/pod-1/protpaths-${each.value.leaf_id}/pathep-[${each.value.intf_id}]"
  encap              = each.value.vlan_encap
  mode               = each.value.trunk_mode
}