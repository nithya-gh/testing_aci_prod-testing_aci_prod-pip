terraform {
  required_providers {
    aci = {
      source = "ciscodevnet/aci"
    }
  }
}



# CONFIGURING VLAN POOL

resource "aci_vlan_pool" "cups_vp" {
  for_each    = var.cups_vp
  name        = each.key
  description = "cups_vp"
  alloc_mode  = "dynamic"
}


# CONFIGURING VLAN POOL - RANGE

resource "aci_ranges" "cups_vp_range" {
  for_each     = var.cups_vlan_range
  vlan_pool_dn = aci_vlan_pool.cups_vp[each.value.vlan_name].id
  from         = each.value.vlan_start
  to           = each.value.vlan_end
  alloc_mode   = each.value.allocation_mode
  role         = "external"
}


# CONFIGURING L3 DOMAIN

resource "aci_l3_domain_profile" "cups_l3_dom" {
  for_each                  = { for k in compact([for k, v in var.cups_domain : v.phy_dom ? "" : k]) : k => var.cups_domain[k] }
  name                      = each.value.name
  relation_infra_rs_vlan_ns = aci_vlan_pool.cups_vp[each.value.vp].id
}
# CONFIGURING PHYSICAL DOMAIN

resource "aci_physical_domain" "cups_phy_dom" {
  for_each                  = { for k in compact([for k, v in var.cups_domain : v.phy_dom ? k : ""]) : k => var.cups_domain[k] }
  name                      = each.value.name
  relation_infra_rs_vlan_ns = aci_vlan_pool.cups_vp[each.value.vp].id
}


# CONFIGURING AAEP - LAYER3 DOMAIN

resource "aci_attachable_access_entity_profile" "cups_l3_aep" {
  for_each                = { for k in compact([for k, v in var.cups_aaep : v.phy_dom ? "" : k]) : k => var.cups_aaep[k] }
  name                    = each.value.aaep
  relation_infra_rs_dom_p = [aci_l3_domain_profile.cups_l3_dom[each.value.domain].id]
}


# CONFIGURING AAEP - PHYSICAL DOMAIN

resource "aci_attachable_access_entity_profile" "cups_phy_aep" {
  for_each                = { for k in compact([for k, v in var.cups_aaep : v.phy_dom ? k : ""]) : k => var.cups_aaep[k] }
  name                    = each.value.aaep
  relation_infra_rs_dom_p = [aci_physical_domain.cups_phy_dom[each.value.domain].id]
}


# CONFIGURING POLICY - LINK POLICY

resource "aci_fabric_if_pol" "link_pol" {
  for_each = var.link_pol
  name     = each.value.name
  auto_neg = each.value.auto
  speed    = each.value.speed
}


# CONFIGURING POLICY - CDP POLICY

resource "aci_cdp_interface_policy" "cdp_pol" {
  for_each = var.cdp_pol
  name     = each.value.name
  admin_st = each.value.state
}
# CONFIGURING POLICY - LLDP POLICY

resource "aci_lldp_interface_policy" "lldp_pol" {
  for_each    = var.lldp_pol
  name        = each.value.name
  admin_rx_st = each.value.rx_state
  admin_tx_st = each.value.tx_state
}


# CONFIGURING POLICY - MCP POLICY

resource "aci_miscabling_protocol_interface_policy" "mcp_pol" {
  for_each = var.mcp_pol
  name     = each.value.name
  admin_st = each.value.state
}


# CONFIGURING POLICY - L2 POLICY

resource "aci_l2_interface_policy" "l2_state_pol" {
  for_each   = var.l2_state_pol
  name       = each.value.name
  vlan_scope = each.value.scope
}


# CONFIGURING POLICY - LACP POLICY

resource "aci_lacp_policy" "lacp_pol" {
  for_each = var.lacp_pol
  name     = each.value.name
  mode     = each.value.state
}

# CONFIGURING POLICY GROUP - ACCESS POLICY GROUP - PHYSICAL

resource "aci_leaf_access_port_policy_group" "cups_phy_acc_pol_grp" {
  for_each                      = var.acc_pol_grp
  name                          = each.value.name
  relation_infra_rs_h_if_pol    = aci_fabric_if_pol.link_pol[each.value.link_pol].id
  relation_infra_rs_cdp_if_pol  = aci_cdp_interface_policy.cdp_pol[each.value.cdp_pol].id
  relation_infra_rs_lldp_if_pol = aci_lldp_interface_policy.lldp_pol[each.value.lldp_pol].id
  relation_infra_rs_mcp_if_pol  = aci_miscabling_protocol_interface_policy.mcp_pol[each.value.mcp_pol].id
  relation_infra_rs_l2_if_pol   = aci_l2_interface_policy.l2_state_pol[each.value.l2_scope_pol].id
   relation_infra_rs_att_ent_p   = aci_attachable_access_entity_profile.cups_phy_aep[each.value.aep_rel].id
}


# CONFIGURING POLICY GROUP - BUNDLE POLICY GROUP - PHYSICAL


resource "aci_leaf_access_bundle_policy_group" "cups_phy_bundle_pol_grp" {
  for_each                      = var.bundle_pol_grp
  name                          = each.value.name
  lag_t                         = each.value.bundle
  relation_infra_rs_h_if_pol    = aci_fabric_if_pol.link_pol[each.value.link_pol].id
  relation_infra_rs_cdp_if_pol  = aci_cdp_interface_policy.cdp_pol[each.value.cdp_pol].id
  relation_infra_rs_lldp_if_pol = aci_lldp_interface_policy.lldp_pol[each.value.lldp_pol].id
  relation_infra_rs_mcp_if_pol  = aci_miscabling_protocol_interface_policy.mcp_pol[each.value.mcp_pol].id
  relation_infra_rs_l2_if_pol   = aci_l2_interface_policy.l2_state_pol[each.value.l2_scope_pol].id
 # relation_infra_rs_att_ent_p   = aci_attachable_access_entity_profile.cups_phy_aep[each.value.aep_rel].id
  relation_infra_rs_lacp_pol    = aci_lacp_policy.lacp_pol[each.value.lacp_pol].id
}


# CONFIGURING LEAF INTERFACE PROFILE

resource "aci_leaf_interface_profile" "cups_lf_int_prof" {
  for_each = var.cups_lf_int_prof
  name     = each.value.name
}


# CONFIGURING LEAF INTERFACE PROFILE - PORT SELECTOR - ACCESS PORT - PHYSICAL

resource "aci_access_port_selector" "cups_lf_port_sel_acc" {
  for_each = { for k in compact([for k, v in var.cups_lf_int_prof : v.access_pol ? k : ""]) : k => var.cups_lf_int_prof[k] }
  #  for_each                       = var.cups_lf_int_prof
  leaf_interface_profile_dn      = aci_leaf_interface_profile.cups_lf_int_prof[each.key].id
  name                           = each.value.sel
  access_port_selector_type      = "range"
  relation_infra_rs_acc_base_grp = aci_leaf_access_port_policy_group.cups_phy_acc_pol_grp[each.value.pol_grp].id
}

# CONFIGURING LEAF INTERFACE PROFILE - PORT SELECTOR - BUNDLE PORT - PHYSICAL

resource "aci_access_port_selector" "cups_lf_port_sel_bundle" {
 for_each = { for k in compact([for k, v in var.cups_lf_int_prof : v.access_pol ? "" : k]) : k => var.cups_lf_int_prof[k] }
  #  for_each                       = var.cups_lf_int_prof
  leaf_interface_profile_dn      = aci_leaf_interface_profile.cups_lf_int_prof[each.key].id
  name                           = each.value.sel
  access_port_selector_type      = "range"
  relation_infra_rs_acc_base_grp = aci_leaf_access_bundle_policy_group.cups_phy_bundle_pol_grp[each.value.pol_grp].id
}

# CONFIGURING LEAF INTERFACE PROFILE - PORT SELECTOR - PORT BLOCK - ACCESS PORT - PHYSICAL

resource "aci_access_port_block" "cups_lf_port_blk_acc" {
  for_each = { for k in compact([for k, v in var.cups_lf_int_prof : v.access_pol ? k : ""]) : k => var.cups_lf_int_prof[k] }
  #  for_each                = var.cups_lf_int_prof
  access_port_selector_dn = aci_access_port_selector.cups_lf_port_sel_acc[each.key].id
  name                    = each.value.blk
  from_card               = "1"
  from_port               = each.value.blkstart
  to_card                 = "1"
  to_port                 = each.value.blkend
}

# CONFIGURING LEAF INTERFACE PROFILE - PORT SELECTOR - PORT BLOCK - BUNDLE PORT - PHYSICAL

resource "aci_access_port_block" "cups_lf_port_blk_bundle" {
  for_each = { for k in compact([for k, v in var.cups_lf_int_prof : v.access_pol ? "" : k]) : k => var.cups_lf_int_prof[k] }
  #  for_each                = var.cups_lf_int_prof
  access_port_selector_dn = aci_access_port_selector.cups_lf_port_sel_bundle[each.key].id
  name                    = each.value.blk
  from_card               = "1"
  from_port               = each.value.blkstart
  to_card                 = "1"
  to_port                 = each.value.blkend
}

# CONFIGURING LEAF PROFILE

resource "aci_leaf_profile" "cups_access_lfprof" {
  for_each                     = var.cups_lf_prof
  name                         = each.value.name
  relation_infra_rs_acc_port_p = [aci_leaf_interface_profile.cups_lf_int_prof[each.value.intprof].id]
}


# CONFIGURING LEAF PROFILE - LEAF SELECTOR
resource "aci_leaf_selector" "cups_access_lfsel" {
  for_each                = var.cups_lf_prof
  leaf_profile_dn         = aci_leaf_profile.cups_access_lfprof[each.key].id
  name                    = each.value.leafsel
  switch_association_type = "range"
}


# CONFIGURING LEAF PROFILE - LEAF SELECTOR - NODE BLOCK

resource "aci_node_block" "cups_access_leaf_nodes" {
  for_each              = var.cups_lf_prof
  switch_association_dn = aci_leaf_selector.cups_access_lfsel[each.value.leafsel].id
  name                  = each.value.nodeblk
  from_                 = each.value.nodefrom
  to_                   = each.value.nodeto
}

resource "aci_vpc_explicit_protection_group" "vpc_domain" {
  for_each                         = var.vpc_domain
  name                             = each.value.name
  switch1                          = each.value.switch1
  switch2                          = each.value.switch2
  vpc_domain_policy                = "default"
  vpc_explicit_protection_group_id = each.value.group
}