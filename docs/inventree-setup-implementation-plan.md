# InvenTree Setup Implementation Plan

**Project:** Scientific-Ops Research Peptide Business Inventory System
**Target System:** InvenTree 1.0.8
**Created:** 2025-11-12
**Status:** Planning Phase

## Overview

This document provides a phased implementation plan for setting up InvenTree as the inventory management system for a research peptide distribution business. The implementation is broken down into manageable phases that can be completed incrementally.

## Implementation Approach

This setup will be implemented in 5 phases:

1. **Foundation** - Core system setup and verification
2. **Data Structure** - Categories, locations, and taxonomies
3. **Business Logic** - Custom fields and workflows
4. **Operations** - Templates, reports, and automation
5. **Integration** - Plugins and external systems

Each phase builds on the previous one and can be completed independently.

---

## Phase 1: Foundation Setup

### 1.1 System Prerequisites

- [ ] Verify InvenTree version 1.0.8 is installed
- [ ] Run database migrations (`python manage.py migrate`)
- [ ] Verify superuser account exists
- [ ] Document environment details (Python version, database type)
- [ ] Test web interface access
- [ ] Verify file upload permissions for media directory

### 1.2 Core Plugin Installation

- [ ] Enable InvenTreeLabel plugin
- [ ] Enable InvenTreeBarcode plugin
- [ ] Enable InvenTreeCurrency plugin
- [ ] Test QR code generation
- [ ] Verify label rendering works

### 1.3 Global Settings Configuration

#### General Settings
- [ ] Set Company Name: "Scientific-Ops Research Supply"
- [ ] Configure Base URL
- [ ] Set Default Currency: USD
- [ ] Add BTC as secondary currency

#### Stock Settings
- [ ] Enable Stock Expiry
- [ ] Enable Batch Codes
- [ ] Enable Serial Numbers
- [ ] Enable Stock Location tracking
- [ ] Enable Track Stock by Supplier
- [ ] Set Expiry Warning Days: 180

#### Barcode Settings
- [ ] Enable Barcode Support
- [ ] Set Barcode Format: QR Code
- [ ] Enable auto-generation for Stock Items

#### Purchase Order Settings
- [ ] Enable Purchase Orders
- [ ] Set PO Reference format: `PO-{ref:04d}`
- [ ] Enable PO Approval requirement

#### Sales Order Settings
- [ ] Enable Sales Orders
- [ ] Set SO Reference format: `SO-{ref:04d}`
- [ ] Enable SO Approval requirement
- [ ] Enable Shipments

#### Label Settings
- [ ] Enable Label Printing
- [ ] Set Default Label Height: 20mm
- [ ] Set Default Label Width: 40mm

#### Build Settings
- [ ] Disable Build Orders (not needed for this business)

---

## Phase 2: Data Structure Setup

### 2.1 Part Categories

#### Research Peptides Hierarchy
- [ ] Create root category: "Research Peptides"
- [ ] Create subcategory: "GLP-1 Agonists"
  - [ ] Add child: "Tirzepatide"
  - [ ] Add child: "Semaglutide"
  - [ ] Add child: "Retatrutide"
- [ ] Create subcategory: "Growth Factors"
  - [ ] Add child: "BPC-157"
  - [ ] Add child: "TB-500"
  - [ ] Add child: "IGF-1 LR3"
- [ ] Create subcategory: "Metabolic Compounds"
  - [ ] Add child: "AOD-9604"
  - [ ] Add child: "MOTS-c"
- [ ] Create subcategory: "Combination Peptides"

#### Consumables Hierarchy
- [ ] Create root category: "Consumables"
- [ ] Create subcategory: "Packaging Materials"
  - [ ] Add child: "Bubble Mailers"
  - [ ] Add child: "Boxes"
  - [ ] Add child: "Bubble Wrap"
  - [ ] Add child: "Thermal Labels"
- [ ] Create subcategory: "Shipping Supplies"
  - [ ] Add child: "Packing Tape"
  - [ ] Add child: "Label Backing Sheets"

#### Testing Services Hierarchy
- [ ] Create root category: "Testing Services"
- [ ] Create subcategory: "Laboratory Analysis"
  - [ ] Add child: "Janoshik Testing"

### 2.2 Stock Location Structure

#### Main Storage Hierarchy
- [ ] Create location: "Main Storage" (structural)
- [ ] Create location: "Main Storage → Receiving" (structural)
  - [ ] Add location: "Quarantine (Awaiting Testing)"
  - [ ] Enable "Requires inspection" flag on Quarantine
- [ ] Create location: "Main Storage → Tested Inventory" (structural)
  - [ ] Add location: "Ready for Sale" (structural)
    - [ ] Add sub-location: "GLP-1 Peptides"
    - [ ] Add sub-location: "Growth Factors"
    - [ ] Add sub-location: "Other Peptides"
  - [ ] Add location: "Quality Hold" (structural)
    - [ ] Add sub-location: "Failed Testing"
    - [ ] Add sub-location: "Near Expiration (180 days)"
- [ ] Create location: "Main Storage → Testing in Progress"
  - [ ] Add location: "Sent to Janoshik"
- [ ] Create location: "Main Storage → Packaging & Supplies" (structural)
  - [ ] Add sub-location: "Bubble Mailers"
  - [ ] Add sub-location: "Boxes"
  - [ ] Add sub-location: "Labels"

#### Fulfillment & Defective Storage
- [ ] Create location: "Fulfilled Orders" (structural)
  - [ ] Add location: "Awaiting Shipment"
- [ ] Create location: "Defective/Recalled"

---

## Phase 3: Business Logic Configuration

### 3.1 Custom Fields - Parts

- [ ] Create field: CAS Number (Text)
  - Model: Part, Name: cas_number, Required: No
- [ ] Create field: Molecular Formula (Text)
  - Model: Part, Name: molecular_formula, Required: No
- [ ] Create field: Molecular Weight (Number)
  - Model: Part, Name: molecular_weight, Units: g/mol, Required: No
- [ ] Create field: Standard Concentration (Text)
  - Model: Part, Name: standard_concentration, Required: Yes (for peptides)

### 3.2 Custom Fields - Stock Items

- [ ] Create field: Janoshik Test URL (URL)
  - Model: StockItem, Name: janoshik_url, Required: No
- [ ] Create field: Janoshik PDF Report (File)
  - Model: StockItem, Name: janoshik_pdf, Required: No
- [ ] Create field: Tested Purity (Number)
  - Model: StockItem, Name: tested_purity, Units: %, Min: 0, Max: 100, Required: No
- [ ] Create field: Tested Amount (Number)
  - Model: StockItem, Name: tested_amount, Units: mg, Required: No
- [ ] Create field: Test Date (Date)
  - Model: StockItem, Name: test_date, Required: No
- [ ] Create field: Testing Cost (Number)
  - Model: StockItem, Name: test_cost, Units: USD, Required: No
- [ ] Create field: Vials Sent for Testing (Integer)
  - Model: StockItem, Name: vials_tested, Default: 0, Required: No

### 3.3 Custom Fields - Purchase Orders

- [ ] Create field: BTC Amount Paid (Number)
  - Model: PurchaseOrder, Name: btc_amount, Required: No
- [ ] Create field: BTC Exchange Rate (Number)
  - Model: PurchaseOrder, Name: btc_exchange_rate, Required: No
- [ ] Create field: BTC Purchase Date (Date)
  - Model: PurchaseOrder, Name: btc_purchase_date, Required: No
- [ ] Create field: Exchange Fees (Number)
  - Model: PurchaseOrder, Name: exchange_fees, Units: USD, Required: No
- [ ] Create field: Supplier COA (File)
  - Model: PurchaseOrder, Name: supplier_coa, Required: No
- [ ] Create field: Supplier Claimed Purity (Number)
  - Model: PurchaseOrder, Name: supplier_purity_claim, Units: %, Min: 0, Max: 100, Required: No
- [ ] Create field: Supplier Communication Notes (Text - Long)
  - Model: PurchaseOrder, Name: supplier_comm_notes, Required: No

### 3.4 Custom Fields - Sales Orders

- [ ] Create field: Age Verified (Checkbox)
  - Model: SalesOrder, Name: age_verified, Required: Yes, Default: False
- [ ] Create field: Research Use Acknowledged (Checkbox)
  - Model: SalesOrder, Name: research_use_ack, Required: Yes, Default: False
- [ ] Create field: Payment Method (Choice)
  - Model: SalesOrder, Name: payment_method, Required: Yes
  - Choices: Credit Card, PayPal, Venmo, CashApp, BTC, ETH, USDC, Cash, Zelle, Wire Transfer
- [ ] Create field: Crypto Amount Received (Text)
  - Model: SalesOrder, Name: crypto_amount, Required: No
- [ ] Create field: Crypto Exchange Rate (Number)
  - Model: SalesOrder, Name: crypto_exchange_rate, Required: No
- [ ] Create field: Payment Fees (Number)
  - Model: SalesOrder, Name: payment_fees, Units: USD, Required: No
- [ ] Create field: Actual Shipping Cost (Number)
  - Model: SalesOrder, Name: actual_shipping_cost, Units: USD, Required: No
- [ ] Create field: Packaging Cost (Number)
  - Model: SalesOrder, Name: packaging_cost, Units: USD, Required: No

### 3.5 Custom Fields - Companies (Suppliers)

- [ ] Create field: Primary Contact Method (Choice)
  - Model: Company, Name: primary_contact_method, Required: Yes
  - Choices: WhatsApp, Telegram, Email, WeChat
- [ ] Create field: Average Delivery Time (Integer)
  - Model: Company, Name: avg_delivery_days, Units: days, Required: No
- [ ] Create field: Reliability Score (Number)
  - Model: Company, Name: reliability_score, Min: 0, Max: 10, Required: No
- [ ] Create field: Purity Accuracy Score (Number)
  - Model: Company, Name: purity_accuracy, Required: No
- [ ] Create field: Current Price Sheet (File)
  - Model: Company, Name: price_sheet, Required: No

### 3.6 Stock Status Codes

#### Keep Default Status Codes
- [ ] Verify default status codes exist:
  - OK (10), Attention Needed (50), Damaged (55), Destroyed (60)
  - Rejected (65), Lost (70), Returned (85)

#### Add Custom Status Codes
- [ ] Create status: "Received - Untested" (Value: 20, Label: warning)
- [ ] Create status: "Testing in Progress" (Value: 30, Label: primary)
- [ ] Create status: "Verified - Ready" (Value: 40, Label: success)
- [ ] Create status: "Available - Untested" (Value: 45, Label: warning)
- [ ] Create status: "Near Expiration" (Value: 52, Label: warning)
- [ ] Create status: "Failed Testing" (Value: 66, Label: danger)

#### Document Workflow
- [ ] Create workflow documentation for status transitions
- [ ] Define criteria for each status code
- [ ] Train team on status meanings and when to use each

### 3.7 Parameter Templates

#### Peptide Parameters
- [ ] Create template: "Purity (HPLC)" (Units: %)
- [ ] Create template: "Concentration" (Units: mg/vial)
- [ ] Create template: "Molecular Weight" (Units: g/mol)
- [ ] Create template: "Storage Temperature" (Units: °C)
- [ ] Create template: "Reconstitution Volume" (Units: mL)
- [ ] Create template: "Shelf Life (Lyophilized)" (Units: months)

#### Consumable Parameters
- [ ] Create template: "Dimensions" (Units: mm)
- [ ] Create template: "Package Quantity" (Units: pieces)

---

## Phase 4: Operations & Templates

### 4.1 Company Setup

#### Your Company
- [ ] Create company: "Scientific-Ops Research Supply"
- [ ] Add company description
- [ ] Add website: https://scientific-ops.com
- [ ] Add primary contact information
- [ ] Set appropriate company flags (not supplier/customer/manufacturer)

#### Supplier Companies
- [ ] Create Supplier #1 (China peptide supplier)
  - [ ] Add company name/code
  - [ ] Set as Supplier and Manufacturer
  - [ ] Add primary contact details
  - [ ] Add WhatsApp/Telegram contact
  - [ ] Set custom fields: contact method, avg delivery time
  - [ ] Set initial reliability score: 8.0
  - [ ] Add notes about specialties and MOQs
- [ ] Create Supplier #2 (backup China supplier)
  - [ ] Complete same setup as Supplier #1
- [ ] Create Supplier #3 (if applicable)
  - [ ] Complete same setup as Supplier #1

### 4.2 Initial Parts Creation

#### Test Peptide Part (Tirzepatide Example)
- [ ] Create part: "Tirzepatide"
- [ ] Set IPN: "TIRZ-10MG"
- [ ] Set category: Research Peptides → GLP-1 Agonists
- [ ] Add description: "GLP-1/GIP dual agonist for metabolic research"
- [ ] Enable flags: Active, Purchaseable, Saleable, Trackable
- [ ] Set custom fields:
  - [ ] CAS Number: 2023788-19-2
  - [ ] Molecular Formula: C225H348N48O68
  - [ ] Molecular Weight: 4813.53
  - [ ] Standard Concentration: 10mg
- [ ] Add parameters:
  - [ ] Purity (HPLC): ≥99.0%
  - [ ] Concentration: 10mg/vial
  - [ ] Storage Temperature: -20°C
  - [ ] Reconstitution Volume: 2mL
  - [ ] Shelf Life: 36 months
- [ ] Set minimum stock: 20 vials
- [ ] Link to suppliers with pricing

#### Additional Peptide Parts
- [ ] Create part: Semaglutide (follow Tirzepatide structure)
- [ ] Create part: Retatrutide (follow Tirzepatide structure)
- [ ] Create part: BPC-157 (follow Tirzepatide structure)
- [ ] Create part: TB-500 (follow Tirzepatide structure)

#### Consumable Parts
- [ ] Create part: Bubble Mailer - Small (6x9)
  - IPN: PKG-BM-69, Category: Consumables → Packaging Materials
  - Set as Consumable, Purchaseable (not Saleable)
  - Minimum stock: 50
- [ ] Create part: Bubble Mailer - Medium (9x12)
- [ ] Create part: Packing Tape
- [ ] Create part: Thermal Labels 4x6

### 4.3 Label Templates

#### Peptide Vial Label (40mm x 20mm)
- [ ] Create new label template: "Peptide Vial Label 40x20mm"
- [ ] Set model type: Stock Item
- [ ] Set dimensions: 40mm x 20mm
- [ ] Implement HTML template with:
  - [ ] Part name and concentration
  - [ ] LOT number and expiry date
  - [ ] QR code (Janoshik URL or stock barcode)
  - [ ] Tested purity percentage (if available)
  - [ ] "FOR RESEARCH USE ONLY" disclaimer
- [ ] Test print label
- [ ] Verify QR code scans correctly

#### Stock Location Label
- [ ] Create template: "Storage Location Label"
- [ ] Set model type: Stock Location
- [ ] Set dimensions: 40mm x 20mm
- [ ] Implement template with location name and QR code
- [ ] Test print for sample location

### 4.4 Report Templates

#### Purchase Order Report
- [ ] Create report template: "Purchase Order Report"
- [ ] Set model type: Purchase Order
- [ ] Design layout including:
  - [ ] Supplier details
  - [ ] Line items with quantities
  - [ ] Pricing (USD)
  - [ ] BTC payment tracking fields
  - [ ] Delivery expectations
- [ ] Test with sample PO

#### Sales Order Packing Slip
- [ ] Create report template: "Packing Slip"
- [ ] Set model type: Sales Order
- [ ] Design layout including:
  - [ ] Customer information (anonymized option)
  - [ ] Order items with batch numbers
  - [ ] "Research Use Only" disclaimers
  - [ ] Handling instructions
- [ ] Test with sample SO

#### Certificate of Analysis (COA)
- [ ] Create report template: "Customer COA"
- [ ] Set model type: Stock Item
- [ ] Design layout including:
  - [ ] Product name and batch number
  - [ ] Janoshik test results (purity, amount)
  - [ ] Link/QR code to Janoshik URL
  - [ ] Test date
  - [ ] Storage recommendations
  - [ ] Legal disclaimers
- [ ] Test with sample stock item

---

## Phase 5: Automation & Integration

### 5.1 Custom Plugin Development

#### Plugin Foundation
- [ ] Create plugin file: `InvenTree/plugins/peptide_business.py`
- [ ] Implement PeptideBusinessPlugin class
- [ ] Add plugin metadata (NAME, SLUG, TITLE, VERSION)
- [ ] Define plugin settings:
  - [ ] EXPIRY_WARNING_DAYS (default: 180)
  - [ ] MIN_PURITY_THRESHOLD (default: 98.0)
  - [ ] AUTO_LOT_GENERATION (default: True)

#### Auto LOT Number Generation
- [ ] Implement `on_stock_item_created()` event handler
- [ ] Define LOT format: `[PEPTIDE-CODE]-[YYYYMMDD]-[###]`
- [ ] Add sequential number generation logic
- [ ] Test with new stock item creation

#### Expiry Alert Automation
- [ ] Implement `check_expiry_alerts()` scheduled task
- [ ] Query items approaching expiration (180 days)
- [ ] Auto-update status to "Near Expiration" (52)
- [ ] (Optional) Configure notification system
- [ ] Set up scheduled task runner

#### Purity Validation
- [ ] Implement `validate_purity()` function
- [ ] Check tested_purity against MIN_PURITY_THRESHOLD
- [ ] Auto-mark as "Failed Testing" (66) if below threshold
- [ ] Test with sample stock items

#### Plugin Installation
- [ ] Copy plugin to InvenTree plugins directory
- [ ] Enable plugin in admin panel
- [ ] Configure plugin settings
- [ ] Verify event handlers trigger correctly

### 5.2 Backup & Maintenance Setup

#### Database Backups
- [ ] Create backup script for database
  - [ ] Django JSON dump: `python manage.py dumpdata`
  - [ ] Or PostgreSQL dump if using Postgres
- [ ] Set up backup directory structure
- [ ] Configure daily automated backups (cron job)
- [ ] Test restore procedure
- [ ] Document backup/restore process

#### Media Files Backup
- [ ] Create backup script for media files
  - [ ] COA documents, price sheets, test PDFs
- [ ] Configure daily automated backups
- [ ] Test restore procedure

#### Maintenance Tasks
- [ ] Document routine maintenance tasks
- [ ] Set up log rotation
- [ ] Configure monitoring/alerting (optional)

---

## Phase 6: Testing & Validation

### 6.1 End-to-End Workflow Testing

#### Receiving Workflow
- [ ] Create test purchase order
- [ ] Receive test stock into Quarantine
- [ ] Verify status: "Received - Untested"
- [ ] Verify LOT number auto-generation
- [ ] Print test vial label

#### Testing Workflow
- [ ] Move sample to "Testing in Progress"
- [ ] Update status: "Testing in Progress"
- [ ] Add Janoshik test data to custom fields
- [ ] Upload test PDF
- [ ] Validate purity threshold check

#### Quality Control
- [ ] Test passing scenario (>98% purity)
  - [ ] Move to "Ready for Sale"
  - [ ] Update status: "Verified - Ready"
- [ ] Test failing scenario (<98% purity)
  - [ ] Verify auto-status to "Failed Testing"
  - [ ] Move to Quality Hold

#### Sales Workflow
- [ ] Create test sales order
- [ ] Verify compliance checkboxes (age, research use)
- [ ] Allocate stock from "Ready for Sale"
- [ ] Generate packing slip
- [ ] Generate COA
- [ ] Test label printing

#### Expiry Workflow
- [ ] Create stock item with near expiry date
- [ ] Run expiry check automation
- [ ] Verify status updates to "Near Expiration"
- [ ] Verify location move alert

### 6.2 Reporting & Analytics Testing

- [ ] Generate supplier performance report
- [ ] Test inventory valuation report
- [ ] Verify low stock alerts
- [ ] Test expiration tracking report
- [ ] Validate custom field data in reports

### 6.3 User Acceptance Testing

- [ ] Train primary user(s) on system
- [ ] Complete 5-10 real transactions
- [ ] Gather feedback on workflow
- [ ] Identify pain points or missing features
- [ ] Document any customization requests

---

## Phase 7: Documentation & Training

### 7.1 Internal Documentation

- [ ] Create quick reference guide for daily operations
- [ ] Document custom field purposes and usage
- [ ] Create workflow diagrams for:
  - [ ] Receiving and quarantine
  - [ ] Testing and QC
  - [ ] Order fulfillment
  - [ ] Returns/defects
- [ ] Document backup/restore procedures
- [ ] Create troubleshooting guide

### 7.2 Training Materials

- [ ] Create video walkthrough of receiving process
- [ ] Create video for order fulfillment
- [ ] Document label printing procedures
- [ ] Create SOPs for:
  - [ ] Receiving shipments
  - [ ] Sending samples to Janoshik
  - [ ] Processing test results
  - [ ] Fulfilling orders
  - [ ] Handling quality issues

### 7.3 Compliance Documentation

- [ ] Document age verification process
- [ ] Create research use disclaimer templates
- [ ] Document record retention policies
- [ ] Create audit trail procedures

---

## Success Criteria

### Phase 1-3 Complete
- [ ] All categories, locations, and custom fields created
- [ ] Status codes and workflows documented
- [ ] At least 5 parts created with full data
- [ ] 2-3 supplier companies configured

### Phase 4-5 Complete
- [ ] All label and report templates functional
- [ ] Custom plugin installed and operational
- [ ] Automated backups running
- [ ] LOT number generation working

### Phase 6-7 Complete
- [ ] 10+ real transactions processed successfully
- [ ] All reports generating correctly
- [ ] Team trained and comfortable with system
- [ ] Documentation complete

### Production Ready
- [ ] System handling daily operations
- [ ] No critical bugs or workflow blockers
- [ ] Backup/restore tested and verified
- [ ] Integration with WooCommerce planned (future phase)

---

## Known Questions & Considerations

### Questions for Clarification

1. **Printer Hardware**: What label printer will be used? (affects template testing)
2. **Database Backend**: Using SQLite, PostgreSQL, or MySQL? (affects backup strategy)
3. **Hosting**: Self-hosted on-premise or cloud? (affects access and backup)
4. **User Access**: Single user or multiple team members? (affects permissions setup)
5. **WooCommerce Timeline**: When will ecommerce integration be needed?

### Technical Considerations

- **Performance**: Current setup assumes <1000 SKUs and <10,000 stock items
- **Scalability**: Plugin automation may need optimization for larger datasets
- **Security**: Ensure proper SSL/TLS for web access, especially for compliance data
- **Compliance**: Research use disclaimers may need legal review
- **Data Privacy**: Consider customer data retention and anonymization policies

### Future Enhancements

- [ ] API integration with WooCommerce
- [ ] Automated supplier price updates
- [ ] Advanced reporting dashboards
- [ ] Email notifications for low stock
- [ ] Customer portal for order tracking (if needed)
- [ ] Integration with shipping carriers (USPS API)

---

## Implementation Timeline Estimate

| Phase | Estimated Time | Complexity |
|-------|----------------|------------|
| Phase 1: Foundation | 2-4 hours | Low |
| Phase 2: Data Structure | 3-5 hours | Low |
| Phase 3: Business Logic | 4-6 hours | Medium |
| Phase 4: Operations | 5-8 hours | Medium |
| Phase 5: Automation | 6-10 hours | High |
| Phase 6: Testing | 4-6 hours | Medium |
| Phase 7: Documentation | 3-5 hours | Low |
| **Total** | **27-44 hours** | - |

**Note:** Timeline assumes familiarity with InvenTree and Django. Add 25-50% time for learning curve if new to the platform.

---

## Support & Resources

- **InvenTree Documentation**: https://docs.inventree.org/
- **Plugin Development Guide**: https://docs.inventree.org/en/latest/extend/plugins/
- **Community Forum**: https://github.com/inventree/InvenTree/discussions
- **Django Template Language**: https://docs.djangoproject.com/en/stable/ref/templates/language/

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-11-12 | Initial implementation plan created |

---

**Next Steps After Plan Approval:**

1. Review and approve this implementation plan
2. Clarify any outstanding questions above
3. Begin Phase 1: Foundation Setup
4. Track progress by checking off items in this document
5. Commit updates to this plan as each phase completes
