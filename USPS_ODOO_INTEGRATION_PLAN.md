# USPS Shipping Integration for Odoo v19 - Comprehensive Implementation Plan

## Executive Summary

This document outlines a comprehensive plan for building a USPS (United States Postal Service) shipping integration module for Odoo v19. The integration will enable Odoo users to:

- Calculate real-time shipping rates for USPS services
- Generate and print shipping labels (domestic and international)
- Track shipments with real-time status updates
- Validate and standardize shipping addresses
- Handle returns and label cancellations
- Support various USPS services (Priority Mail, Ground Advantage, Priority Mail Express, etc.)

**Critical Note**: As of August 2025, USPS has migrated from legacy Web Tools APIs to a new cloud-based API platform. The legacy API will be fully retired on **January 25, 2026**. This integration will be built using the **new USPS API platform** at developer.usps.com.

---

## Table of Contents

1. [Background and Context](#background-and-context)
2. [USPS API Overview](#usps-api-overview)
3. [Odoo v19 Shipping Architecture](#odoo-v19-shipping-architecture)
4. [Technical Requirements](#technical-requirements)
5. [Module Architecture](#module-architecture)
6. [Implementation Phases](#implementation-phases)
7. [API Integration Details](#api-integration-details)
8. [Testing Strategy](#testing-strategy)
9. [Deployment and Maintenance](#deployment-and-maintenance)
10. [Compliance and Requirements](#compliance-and-requirements)
11. [Timeline and Resources](#timeline-and-resources)
12. [Risks and Mitigation](#risks-and-mitigation)

---

## Background and Context

### Current State

- **Odoo v19**: Latest version with enhanced shipping carrier framework
- **USPS API Migration**: USPS completed migration to cloud-based APIs in August 2025
- **Existing Solutions**: Commercial USPS modules exist for older Odoo versions (8-12), but:
  - Most use deprecated Web Tools API
  - Not updated for Odoo v19
  - Proprietary/closed source with restrictive licenses
  - No support for new USPS API platform

### Business Value

A modern USPS integration provides:
- **Cost savings**: Access to commercial USPS rates and discounts
- **Automation**: Eliminate manual shipping label creation
- **Customer experience**: Real-time tracking and delivery estimates
- **Operational efficiency**: Streamlined fulfillment workflow
- **Market reach**: Support for both domestic and international shipping

---

## USPS API Overview

### API Platform Migration

**Critical Timeline**:
- **August 24, 2025**: USPS redirected APIs to cloud environment
- **January 25, 2026**: Legacy Web Tools API fully retired
- **Action Required**: Must use new API platform at https://developer.usps.com

### Available APIs

The new USPS API platform includes:

#### 1. **Domestic Labels API (v3.0)**
- Create domestic shipping labels with Intelligent Mail Package Barcodes (IMpb)
- Supports formats: PDF, TIFF, SVG, JPG, ZPL203DPI, ZPL300DPI
- Validates addresses and confirms product availability
- Calculates postage automatically
- Generates Shipping Services Files (Publication 199 compliant)

#### 2. **International Labels API (v3.0)**
- Create international shipping labels
- Generates customs forms
- Supports formats: TIFF, PDF
- Confirms product availability
- Calculates international postage

#### 3. **Domestic Pricing API (v3.0)**
- Real-time rate calculation for domestic shipments
- Supports services:
  - USPS Ground Advantage
  - Priority Mail
  - Priority Mail Express
  - Parcel Select
  - Parcel Select Lightweight
  - Library Mail
  - Media Mail
  - Bound Printed Matter
- Inputs: ZIP codes, weight, dimensions, processing category, extra services

#### 4. **International Pricing API (v3.0)**
- Calculate rates for international shipments
- Country-specific pricing
- Customs value consideration

#### 5. **Addresses API**
- Address validation and standardization
- ZIP Code verification
- City and state name correction
- USPS addressing standards compliance

#### 6. **Tracking API**
- Real-time package tracking
- Scan event history with date, time, location
- Delivery status and confirmation
- Included free with Intelligent Mail Package Barcode (IMpb)

#### 7. **Service Standards API**
- Delivery time estimates
- Service availability by origin/destination

#### 8. **Locations API**
- Find USPS post offices and locations
- Drop-off point information

### Authentication

**OAuth 2.0 Client Credentials Flow**:
- All APIs require OAuth 2.0 Bearer token
- Token valid for **8 hours**
- Requires Consumer Key and Secret from developer portal
- Endpoints:
  - **Test (TEM)**: https://apis-tem.usps.com/oauth2/v3/token
  - **Production**: https://apis.usps.com/oauth2/v3/token

### Rate Limits

- **Default quota**: 60 calls per hour per API
- May require quota increase for production use
- Monitor usage to avoid throttling

### Requirements for Label APIs

**Additional enrollment required**:
1. **USPS Ship Account**: Outbound and return labels
2. **Enterprise Payment Account**: For postage payment
3. **Developer Portal Approval**: Enhanced permissions for label generation

---

## Odoo v19 Shipping Architecture

### Core Models

#### 1. **delivery.carrier**
Base model for all shipping providers.

**Key fields**:
- `name`: Carrier name (e.g., "USPS Priority Mail")
- `delivery_type`: Selection field (add 'usps' option)
- `integration_level`: 'rate_and_ship' (get rates + generate labels)
- `prod_environment`: Boolean for production vs test mode
- `margin`: Percentage to add to base rate
- `free_over`: Enable free shipping over amount

**USPS-specific configuration fields to add**:
- `usps_consumer_key`: OAuth Consumer Key
- `usps_consumer_secret`: OAuth Consumer Secret (stored securely)
- `usps_account_number`: USPS Ship account number
- `usps_default_package_type`: Default packaging type
- `usps_label_format`: PDF, ZPL, etc.
- `usps_label_size`: 4x6, 8.5x11, etc.

#### 2. **stock.picking**
Delivery orders (shipments).

**USPS fields to add**:
- `usps_tracking_number`: Tracking/IMpb barcode
- `usps_label_data`: Binary label file
- `usps_label_format`: Format of stored label
- `usps_service_type`: Selected USPS service
- `usps_package_location`: Package identifier
- `usps_shipping_cost`: Actual postage cost

### Required Methods

#### Rate Calculation
```python
def usps_rate_shipment(self, order):
    """
    Calculate USPS shipping rates.

    Args:
        order: sale.order or stock.picking

    Returns:
        dict: {
            'success': bool,
            'price': float,
            'error_message': str,
            'warning_message': str
        }
    """
```

#### Label Generation
```python
def usps_send_shipping(self, pickings):
    """
    Generate USPS shipping labels.

    Args:
        pickings: stock.picking recordset

    Returns:
        list: [{
            'exact_price': float,
            'tracking_number': str,
            'label': binary data
        }]
    """
```

#### Tracking
```python
def usps_get_tracking_link(self, picking):
    """
    Generate tracking URL.

    Args:
        picking: stock.picking record

    Returns:
        str: USPS tracking URL
    """
```

#### Cancellation
```python
def usps_cancel_shipment(self, picking):
    """
    Cancel/void shipping label.

    Args:
        picking: stock.picking record

    Returns:
        bool: Success status
    """
```

### Integration Points

1. **Sales Order**: Rate calculation during checkout
2. **Delivery Order**: Label generation on validation
3. **Inventory**: Package dimension/weight requirements
4. **Product**: Individual product weight/dimensions
5. **Partner (Customer)**: Address validation
6. **Company**: Sender/origin address configuration

---

## Technical Requirements

### Dependencies

#### Python Libraries
```python
# requirements.txt or __manifest__.py
dependencies = [
    'requests>=2.31.0',  # HTTP client for API calls
    'python-dateutil',    # Date/time handling
    'pytz',              # Timezone support
]
```

#### Odoo Modules
```python
# __manifest__.py
'depends': [
    'delivery',          # Core delivery framework
    'stock',             # Inventory/warehouse
    'sale',              # Sales orders
    'product',           # Product weights/dimensions
]
```

### System Requirements

- **Odoo Version**: 19.0+
- **Python**: 3.10+ (Odoo v19 requirement)
- **Database**: PostgreSQL 12+
- **SSL/TLS**: Required for API communication
- **Network**: Outbound HTTPS access to apis.usps.com

### USPS Account Requirements

1. **USPS Developer Portal Account**
   - Register at https://developer.usps.com
   - Create application to get OAuth credentials
   - Request production access

2. **USPS Ship Account**
   - Enrollment required for label generation
   - Both outbound and return label capability

3. **Enterprise Payment Account**
   - For postage payment
   - Can use existing business USPS account

4. **Business Requirements**
   - Valid business or personal account
   - Payment method on file
   - Compliance with USPS shipping policies

---

## Module Architecture

### Module Structure

```
delivery_usps/
├── __init__.py
├── __manifest__.py
├── models/
│   ├── __init__.py
│   ├── delivery_carrier.py      # Main carrier model
│   ├── stock_picking.py          # Shipping/picking extensions
│   ├── usps_service.py           # USPS service types
│   └── res_company.py            # Company configuration
├── wizards/
│   ├── __init__.py
│   └── choose_delivery_package.py # Package selection
├── views/
│   ├── delivery_carrier_views.xml
│   ├── stock_picking_views.xml
│   └── res_config_settings_views.xml
├── data/
│   ├── delivery_usps_data.xml    # Service types data
│   └── ir_cron_data.xml          # Scheduled actions
├── static/
│   └── description/
│       ├── icon.png
│       └── index.html
├── security/
│   └── ir.model.access.csv
├── lib/
│   ├── __init__.py
│   ├── usps_request.py           # API client
│   ├── usps_auth.py              # OAuth handling
│   └── usps_response.py          # Response parsing
└── tests/
    ├── __init__.py
    ├── test_usps_rate.py
    ├── test_usps_label.py
    └── test_usps_tracking.py
```

### Key Components

#### 1. API Client (`lib/usps_request.py`)

Handles all USPS API communication:

```python
class USPSRequest:
    """USPS API Client"""

    def __init__(self, consumer_key, consumer_secret, prod_environment):
        self.consumer_key = consumer_key
        self.consumer_secret = consumer_secret
        self.base_url = (
            'https://apis.usps.com' if prod_environment
            else 'https://apis-tem.usps.com'
        )
        self._token = None
        self._token_expiry = None

    def _get_access_token(self):
        """Get OAuth 2.0 access token (cached for 8 hours)"""
        pass

    def _make_request(self, method, endpoint, data=None):
        """Make authenticated API request"""
        pass

    def get_rates(self, origin_zip, dest_zip, weight, dimensions, services):
        """Get shipping rates"""
        pass

    def create_label(self, shipment_data):
        """Create shipping label"""
        pass

    def track_package(self, tracking_number):
        """Get tracking information"""
        pass

    def validate_address(self, address_data):
        """Validate/standardize address"""
        pass
```

#### 2. Delivery Carrier Extension (`models/delivery_carrier.py`)

```python
class DeliveryCarrier(models.Model):
    _inherit = 'delivery.carrier'

    # Extend delivery_type selection
    delivery_type = fields.Selection(
        selection_add=[('usps', 'USPS')],
        ondelete={'usps': 'set default'}
    )

    # USPS Configuration
    usps_consumer_key = fields.Char(string='USPS Consumer Key')
    usps_consumer_secret = fields.Char(string='USPS Consumer Secret')
    usps_account_number = fields.Char(string='USPS Account Number')
    usps_service_type = fields.Many2one('usps.service', string='USPS Service')
    usps_label_format = fields.Selection([
        ('PDF', 'PDF'),
        ('ZPL203', 'ZPL 203 DPI'),
        ('ZPL300', 'ZPL 300 DPI'),
        ('TIFF', 'TIFF'),
    ], default='PDF')
    usps_label_size = fields.Selection([
        ('4x6', '4" x 6" Label'),
        ('letter', '8.5" x 11" Letter'),
    ], default='4x6')

    def usps_rate_shipment(self, order):
        """Calculate USPS rate"""
        pass

    def usps_send_shipping(self, pickings):
        """Generate USPS label"""
        pass

    def usps_get_tracking_link(self, picking):
        """Get tracking URL"""
        return f'https://tools.usps.com/go/TrackConfirmAction?tLabels={picking.usps_tracking_number}'

    def usps_cancel_shipment(self, picking):
        """Cancel label"""
        pass
```

#### 3. Stock Picking Extension (`models/stock_picking.py`)

```python
class StockPicking(models.Model):
    _inherit = 'stock.picking'

    usps_tracking_number = fields.Char(string='USPS Tracking Number')
    usps_label_data = fields.Binary(string='USPS Label', attachment=True)
    usps_label_format = fields.Char(string='Label Format')
    usps_service_type = fields.Char(string='USPS Service')
    usps_shipping_cost = fields.Float(string='USPS Shipping Cost')

    def action_print_usps_label(self):
        """Print USPS label"""
        pass

    def action_track_usps(self):
        """Open tracking page"""
        pass
```

#### 4. Service Types (`models/usps_service.py`)

```python
class USPSService(models.Model):
    _name = 'usps.service'
    _description = 'USPS Service Types'

    name = fields.Char(string='Service Name', required=True)
    code = fields.Char(string='Service Code', required=True)
    service_type = fields.Selection([
        ('domestic', 'Domestic'),
        ('international', 'International'),
    ], required=True)
    max_weight = fields.Float(string='Max Weight (lbs)')
    description = fields.Text(string='Description')
```

---

## Implementation Phases

### Phase 1: Foundation (Weeks 1-2)

**Goal**: Set up module structure and authentication

**Tasks**:
1. Create module structure and files
2. Define `__manifest__.py` with dependencies
3. Implement OAuth 2.0 authentication
4. Create API client base class with token management
5. Set up configuration views for USPS credentials
6. Implement test/production environment switching
7. Create unit tests for authentication

**Deliverables**:
- Module installable in Odoo v19
- OAuth token retrieval working
- Configuration interface functional

### Phase 2: Rate Calculation (Weeks 3-4)

**Goal**: Implement real-time rate quotes

**Tasks**:
1. Implement Domestic Pricing API integration
2. Implement International Pricing API integration
3. Create service type data (Priority Mail, Ground Advantage, etc.)
4. Extend `delivery.carrier` model with USPS fields
5. Implement `usps_rate_shipment()` method
6. Handle package dimensions and weight validation
7. Support multiple package shipments
8. Add margin/markup configuration
9. Implement error handling and logging
10. Create tests for rate calculation

**Deliverables**:
- Rate calculation on sales orders
- Multiple service options displayed
- Weight/dimension validation working

### Phase 3: Address Validation (Week 5)

**Goal**: Validate and standardize addresses

**Tasks**:
1. Integrate Addresses API
2. Implement address validation on customer records
3. Add address correction suggestions
4. Validate addresses before rate calculation
5. Handle address validation errors gracefully
6. Create tests for address validation

**Deliverables**:
- Address validation on save
- Corrected address suggestions
- Prevention of invalid addresses

### Phase 4: Label Generation (Weeks 6-8)

**Goal**: Generate and print shipping labels

**Tasks**:
1. Implement Domestic Labels API integration
2. Implement International Labels API integration
3. Extend `stock.picking` model with USPS fields
4. Implement `usps_send_shipping()` method
5. Support multiple label formats (PDF, ZPL, TIFF)
6. Support multiple label sizes (4x6, 8.5x11)
7. Store label data in Odoo
8. Implement label printing action
9. Handle label generation errors
10. Generate Intelligent Mail Package Barcode (IMpb)
11. Create Shipping Services Files
12. Create tests for label generation

**Deliverables**:
- Label generation from delivery orders
- Label printing/download
- IMpb barcode tracking numbers
- Support for various formats/sizes

### Phase 5: Tracking (Week 9)

**Goal**: Track shipments in real-time

**Tasks**:
1. Integrate Tracking API
2. Implement `usps_get_tracking_link()` method
3. Add tracking number to delivery orders
4. Create tracking status updates
5. Implement scheduled tracking updates (cron job)
6. Add tracking portal for customers
7. Create tests for tracking

**Deliverables**:
- Tracking numbers on delivery orders
- Real-time tracking status
- Customer tracking portal
- Automated status updates

### Phase 6: Advanced Features (Weeks 10-11)

**Goal**: Add advanced functionality

**Tasks**:
1. Implement label cancellation (`usps_cancel_shipment()`)
2. Add insurance support
3. Implement signature confirmation
4. Add Saturday/Sunday delivery options
5. Support return labels
6. Implement package pickup scheduling
7. Add delivery notifications
8. Create shipping reports/analytics
9. Implement multi-carrier comparison
10. Create tests for advanced features

**Deliverables**:
- Label cancellation
- Extra services (insurance, signature, etc.)
- Return label generation
- Pickup scheduling

### Phase 7: Testing & Documentation (Week 12)

**Goal**: Comprehensive testing and documentation

**Tasks**:
1. Complete unit test coverage (>80%)
2. Perform integration testing with USPS test environment
3. User acceptance testing (UAT)
4. Performance testing and optimization
5. Security audit
6. Create user documentation
7. Create developer/API documentation
8. Create installation guide
9. Record demo videos

**Deliverables**:
- Full test coverage
- User manual
- API documentation
- Installation guide

### Phase 8: Production Deployment (Week 13)

**Goal**: Launch to production

**Tasks**:
1. USPS production API approval
2. Production credentials setup
3. Module packaging for Odoo Apps Store
4. Security review and penetration testing
5. Load testing
6. Production deployment
7. Monitoring setup
8. Support channel creation

**Deliverables**:
- Production-ready module
- Monitoring dashboards
- Support documentation

---

## API Integration Details

### Rate Calculation Flow

```
User selects carrier on sales order
    ↓
Odoo calls usps_rate_shipment()
    ↓
Validate order data (weight, dimensions, addresses)
    ↓
Get OAuth token (cached)
    ↓
Call Domestic/International Pricing API
    ↓
Parse response and extract rates
    ↓
Apply margin/markup if configured
    ↓
Return rate to Odoo
    ↓
Display rate to user
```

### Label Generation Flow

```
User validates delivery order
    ↓
Odoo calls usps_send_shipping()
    ↓
Validate picking data
    ↓
Check for USPS Ship enrollment
    ↓
Get OAuth token (cached)
    ↓
Call Domestic/International Labels API
    ↓
Receive label data and tracking number
    ↓
Store label in Odoo (binary field)
    ↓
Save tracking number to picking
    ↓
Generate Shipping Services File if required
    ↓
Return label to user
```

### Tracking Update Flow

```
Scheduled action runs (e.g., every hour)
    ↓
Find all pickings with USPS tracking numbers
    ↓
Filter for undelivered shipments
    ↓
For each tracking number:
    ↓
    Get OAuth token
    ↓
    Call Tracking API
    ↓
    Parse scan events
    ↓
    Update picking notes/status
    ↓
    Send notifications if configured
```

### Error Handling Strategy

```python
class USPSException(Exception):
    """Base exception for USPS API errors"""
    pass

class USPSAuthenticationError(USPSException):
    """OAuth authentication failed"""
    pass

class USPSRateLimitError(USPSException):
    """Rate limit exceeded"""
    pass

class USPSValidationError(USPSException):
    """Invalid input data"""
    pass

# In methods, handle gracefully:
try:
    result = usps_client.get_rates(...)
except USPSAuthenticationError:
    return {'success': False, 'error_message': 'USPS authentication failed. Check credentials.'}
except USPSRateLimitError:
    return {'success': False, 'error_message': 'Rate limit exceeded. Try again later.'}
except Exception as e:
    _logger.error('USPS API error: %s', e)
    return {'success': False, 'error_message': 'Unexpected error. Contact support.'}
```

---

## Testing Strategy

### Unit Tests

**Coverage goals**: >80% code coverage

**Test files**:
- `tests/test_usps_auth.py`: OAuth token retrieval and caching
- `tests/test_usps_rate.py`: Rate calculation logic
- `tests/test_usps_label.py`: Label generation
- `tests/test_usps_tracking.py`: Tracking updates
- `tests/test_usps_address.py`: Address validation

**Mock API responses** for deterministic testing:

```python
def test_usps_rate_domestic(self):
    """Test domestic rate calculation"""
    carrier = self.env['delivery.carrier'].create({
        'name': 'USPS Priority Mail',
        'delivery_type': 'usps',
        'usps_consumer_key': 'test_key',
        'usps_consumer_secret': 'test_secret',
        'prod_environment': False,
    })

    order = self.env['sale.order'].create({...})

    with mock.patch('...USPSRequest.get_rates') as mock_rates:
        mock_rates.return_value = {
            'success': True,
            'price': 15.50,
        }

        result = carrier.usps_rate_shipment(order)

        self.assertTrue(result['success'])
        self.assertEqual(result['price'], 15.50)
```

### Integration Tests

**Test with USPS test environment**:
- Use test credentials from USPS developer portal
- Test full workflows end-to-end
- Verify label generation produces valid IMpb barcodes
- Confirm tracking numbers are valid format

### User Acceptance Testing (UAT)

**Test scenarios**:
1. Configure USPS credentials
2. Create sales order with USPS shipping
3. Get multiple rate quotes
4. Select USPS service
5. Validate delivery order
6. Generate and print label
7. Track shipment
8. Cancel label
9. Process return
10. Generate reports

### Performance Testing

**Metrics to measure**:
- Rate calculation response time (<2 seconds)
- Label generation time (<5 seconds)
- Token caching effectiveness
- Database query optimization
- Concurrent user handling

### Security Testing

**Focus areas**:
- OAuth credential storage (encrypted)
- SQL injection prevention (ORM usage)
- XSS prevention (proper escaping)
- Access control (security groups)
- API key exposure prevention

---

## Deployment and Maintenance

### Installation

**Requirements**:
1. Odoo v19 installation
2. Python dependencies installed
3. USPS developer account with credentials
4. USPS Ship enrollment

**Steps**:
```bash
# 1. Copy module to Odoo addons directory
cp -r delivery_usps /opt/odoo/addons/

# 2. Update module list
odoo-bin -u delivery_usps -d <database>

# 3. Install module via Apps menu
# Search for "USPS" and click Install

# 4. Configure credentials
# Settings > Inventory > Delivery Methods > Create USPS Carrier
```

### Configuration

**Initial setup**:
1. Navigate to Inventory > Configuration > Delivery Methods
2. Create new delivery method
3. Select "USPS" as Shipping Provider
4. Enter OAuth credentials from USPS developer portal
5. Enter USPS account number
6. Select default service type
7. Configure label format and size preferences
8. Set test/production environment
9. Test connection
10. Activate method

### Monitoring

**Key metrics to track**:
- API success rate
- Average response times
- Token refresh failures
- Label generation errors
- Tracking update frequency
- Rate limit proximity

**Logging**:
```python
import logging
_logger = logging.getLogger(__name__)

# Log all API interactions
_logger.info('USPS API request: %s', endpoint)
_logger.debug('USPS API payload: %s', data)
_logger.error('USPS API error: %s', error)
```

**Odoo logging configuration**:
```ini
[options]
log_level = info
log_handler = :INFO,werkzeug:WARNING,odoo.addons.delivery_usps:DEBUG
```

### Maintenance Tasks

**Regular**:
- Monitor API usage against quotas
- Review error logs weekly
- Update service types as USPS adds/removes services
- Test label generation monthly
- Verify tracking updates working

**Periodic**:
- Update module for Odoo version upgrades
- Review and update USPS API integration for API changes
- Security patches as needed
- Performance optimization

**Emergency**:
- API credential rotation if compromised
- Rollback procedures for critical issues
- Failover to manual shipping if API down

### Support

**Support channels**:
1. **Documentation**: User manual and troubleshooting guide
2. **Issue tracker**: GitHub issues or internal ticketing
3. **Email support**: For urgent issues
4. **Community forum**: For general questions

**Common issues and solutions**:
| Issue | Cause | Solution |
|-------|-------|----------|
| "Authentication failed" | Invalid/expired credentials | Check consumer key/secret, regenerate if needed |
| "Rate limit exceeded" | Too many API calls | Wait for quota reset, request increase |
| "Invalid address" | Address validation failed | Correct address, use USPS format |
| "Label generation failed" | Missing USPS Ship enrollment | Complete enrollment at usps.com |
| "Tracking not updating" | Cron job not running | Check scheduled actions in Odoo |

---

## Compliance and Requirements

### USPS Requirements

**Enrollment**:
- **USPS Ship Account**: Required for label generation
  - Sign up at https://www.usps.com/ship/
  - Complete identity verification
  - Add payment method

- **Enterprise Payment Account**: Required for commercial rates
  - Link to business USPS account
  - Set up automatic payment

**Policies**:
- Comply with USPS Domestic Mail Manual (DMM)
- Follow Publication 199 for shipping services files
- Adhere to addressing standards
- Proper use of IMpb barcodes
- Accurate postage payment

### Data Handling

**Privacy**:
- Customer address data encrypted in transit (HTTPS)
- Secure storage of OAuth credentials
- GDPR compliance for international addresses
- Data retention policies

**Security**:
- OAuth credentials stored encrypted in Odoo
- Access control via Odoo security groups
- Audit trail for all shipping operations
- Regular security updates

### Label Requirements

**Domestic Labels**:
- Must include IMpb barcode
- Correct service type marking
- Proper addressing format
- Required data elements per DMM

**International Labels**:
- Customs forms (CN22/CN23)
- Accurate product descriptions
- Correct HS codes
- Value declarations

### Testing and Certification

**USPS Test Environment**:
- Use test credentials during development
- Validate all workflows in test mode
- Confirm IMpb format compliance
- Test label scanning readability

**Production Approval**:
- Submit for USPS review if required
- Complete any certification processes
- Obtain production credentials

---

## Timeline and Resources

### Estimated Timeline

**Total Duration**: 13 weeks (3 months)

| Phase | Duration | Dependencies |
|-------|----------|--------------|
| 1. Foundation | 2 weeks | - |
| 2. Rate Calculation | 2 weeks | Phase 1 |
| 3. Address Validation | 1 week | Phase 1 |
| 4. Label Generation | 3 weeks | Phases 1, 2, 3 + USPS enrollment |
| 5. Tracking | 1 week | Phase 4 |
| 6. Advanced Features | 2 weeks | Phases 1-5 |
| 7. Testing & Documentation | 1 week | Phases 1-6 |
| 8. Production Deployment | 1 week | Phases 1-7 + USPS production approval |

**Parallel work opportunities**:
- Address validation can be developed alongside rate calculation
- Documentation can be written during development
- Testing can be done incrementally per phase

### Resource Requirements

#### Development Team

**Core Team**:
- **1 Senior Odoo Developer** (full-time, 13 weeks)
  - Odoo ORM expertise
  - Python proficiency
  - API integration experience
  - Security knowledge

- **1 QA Engineer** (half-time, weeks 7-13)
  - Test automation
  - Security testing
  - UAT coordination

- **1 Technical Writer** (quarter-time, weeks 10-13)
  - User documentation
  - API documentation
  - Video tutorials

**Supporting Roles**:
- **Project Manager** (10% time, ongoing)
- **DevOps Engineer** (consultation, deployment phase)
- **USPS Account Manager** (for enrollment support)

#### Infrastructure

**Development**:
- Development Odoo instance
- USPS test environment credentials
- Version control (Git repository)
- CI/CD pipeline
- Test coverage tools

**Production**:
- Production Odoo instance
- USPS production credentials
- Monitoring tools (e.g., Sentry, Prometheus)
- Logging aggregation

#### Costs

**Development**:
- Developer time: 13 weeks × $80-150/hour
- QA time: 6 weeks × $60-100/hour
- Documentation: 4 weeks × $50-80/hour

**USPS Costs**:
- Developer portal: Free
- Test environment: Free
- USPS Ship enrollment: Free
- Production API usage: Free (within quotas)
- Postage costs: Pay-as-you-go

**Infrastructure**:
- Development server: ~$50-100/month
- Monitoring tools: ~$20-50/month
- SSL certificates: Free (Let's Encrypt)

**Total Estimated Cost**: $15,000 - $30,000
(Varies based on hourly rates and team location)

---

## Risks and Mitigation

### Technical Risks

#### Risk 1: USPS API Changes
**Probability**: Medium
**Impact**: High
**Mitigation**:
- Monitor USPS developer portal for announcements
- Implement API version detection
- Build abstraction layer for easier updates
- Subscribe to USPS API mailing list

#### Risk 2: Rate Limit Constraints
**Probability**: Medium
**Impact**: Medium
**Mitigation**:
- Implement aggressive token caching
- Request quota increase before production
- Add rate limiting on Odoo side
- Queue API requests during high traffic
- Show cached rates when possible

#### Risk 3: OAuth Token Management
**Probability**: Low
**Impact**: High
**Mitigation**:
- Implement robust token caching (7-hour expiry)
- Automatic token refresh before expiry
- Retry logic for authentication failures
- Secure credential storage

#### Risk 4: Label Format Compatibility
**Probability**: Low
**Impact**: Medium
**Mitigation**:
- Test multiple label formats (PDF, ZPL, etc.)
- Support multiple sizes (4x6, 8.5x11)
- Validate barcode scanning with USPS
- Provide format selection options

### Business Risks

#### Risk 5: USPS Enrollment Delays
**Probability**: Medium
**Impact**: High
**Mitigation**:
- Start enrollment process early (Phase 1)
- Prepare all required documentation upfront
- Follow up regularly with USPS
- Have backup manual process

#### Risk 6: Insufficient Testing Environment
**Probability**: Low
**Impact**: High
**Mitigation**:
- Use USPS test environment extensively
- Create comprehensive test data sets
- Involve actual users in UAT
- Test with various shipping scenarios

#### Risk 7: Scope Creep
**Probability**: High
**Impact**: Medium
**Mitigation**:
- Define clear MVP requirements
- Implement phased approach
- Document future enhancements separately
- Regular stakeholder reviews

### Operational Risks

#### Risk 8: Production API Approval Delays
**Probability**: Medium
**Impact**: High
**Mitigation**:
- Submit for approval early (week 10)
- Ensure all requirements met before submission
- Maintain communication with USPS
- Have contingency timeline

#### Risk 9: Security Vulnerabilities
**Probability**: Low
**Impact**: High
**Mitigation**:
- Follow OWASP security guidelines
- Code review all API interactions
- Security testing before production
- Regular security updates

#### Risk 10: Performance Issues
**Probability**: Medium
**Impact**: Medium
**Mitigation**:
- Performance testing throughout development
- Optimize database queries
- Implement caching strategies
- Load testing before production

---

## Success Criteria

### Functional Requirements

✅ **Rate calculation**:
- Real-time rates for domestic shipments
- Real-time rates for international shipments
- Support for multiple services
- Accurate weight/dimension handling

✅ **Label generation**:
- Create domestic labels
- Create international labels with customs
- Generate valid IMpb barcodes
- Support multiple formats (PDF, ZPL)

✅ **Tracking**:
- Tracking number assignment
- Real-time tracking updates
- Customer tracking portal
- Delivery notifications

✅ **Address validation**:
- Validate US addresses
- Suggest corrections
- Prevent invalid addresses

✅ **Administration**:
- Easy credential configuration
- Test/production mode switching
- Error logging and monitoring
- Label cancellation

### Performance Requirements

- Rate calculation: <2 seconds
- Label generation: <5 seconds
- Tracking updates: <3 seconds
- 99.5% API success rate
- Support for 100+ concurrent users

### Quality Requirements

- Test coverage: >80%
- Zero critical security vulnerabilities
- Documentation complete and accurate
- User satisfaction: >4/5 stars

---

## Next Steps

### Immediate Actions (Week 1)

1. **Create USPS Developer Account**
   - Register at https://developer.usps.com
   - Create test application
   - Obtain test OAuth credentials

2. **Set Up Development Environment**
   - Install Odoo v19 development instance
   - Create module structure
   - Set up Git repository
   - Configure development database

3. **Begin USPS Ship Enrollment**
   - Sign up at https://www.usps.com/ship/
   - Complete identity verification
   - Prepare business documentation

4. **Initial Planning**
   - Refine requirements with stakeholders
   - Set up project tracking (Jira, Trello, etc.)
   - Schedule regular check-ins
   - Assign team members

### Development Kickoff Checklist

- [ ] USPS developer credentials obtained
- [ ] Odoo v19 development environment ready
- [ ] Module structure created
- [ ] Git repository initialized
- [ ] Team members onboarded
- [ ] Project plan reviewed and approved
- [ ] USPS Ship enrollment initiated
- [ ] Test data prepared
- [ ] Documentation templates created

---

## Appendix

### Useful Resources

**USPS Developer Resources**:
- Developer Portal: https://developer.usps.com
- API Catalog: https://developer.usps.com/apis
- OAuth Documentation: https://developer.usps.com/oauth
- Onboarding Guide: https://www.usps.com/business/web-tools-apis/onboarding-guide.pdf
- API Examples (GitHub): https://github.com/USPS/api-examples

**Odoo Resources**:
- Odoo v19 Documentation: https://www.odoo.com/documentation/19.0
- Delivery Module Docs: https://www.odoo.com/documentation/19.0/applications/inventory_and_mrp/inventory/shipping_receiving/setup_configuration/third_party_shipper.html
- OCA Delivery Carrier: https://github.com/OCA/delivery-carrier
- Odoo Developer Documentation: https://www.odoo.com/documentation/19.0/developer.html

**USPS Policies**:
- Domestic Mail Manual: https://pe.usps.com/DMM300/
- Publication 199: https://postalpro.usps.com/publications
- Addressing Standards: https://postalpro.usps.com/addressing

### Glossary

- **IMpb**: Intelligent Mail Package Barcode - USPS tracking barcode standard
- **DMM**: Domestic Mail Manual - USPS policies and regulations
- **OAuth**: Open Authentication - Security protocol for API access
- **ZPL**: Zebra Programming Language - Label printer format
- **eVS**: Electronic Verification System - USPS high-volume shipping system
- **CN22/CN23**: Customs declaration forms for international mail
- **HS Code**: Harmonized System code for customs classification
- **DIM Weight**: Dimensional weight - Pricing based on package size
- **OCA**: Odoo Community Association - Open source Odoo modules

### Sample API Requests

#### Get OAuth Token
```bash
curl -X POST https://apis-tem.usps.com/oauth2/v3/token \
  -H "Content-Type: application/json" \
  -d '{
    "client_id": "YOUR_CONSUMER_KEY",
    "client_secret": "YOUR_CONSUMER_SECRET",
    "grant_type": "client_credentials"
  }'
```

#### Get Domestic Rate
```bash
curl -X POST https://apis-tem.usps.com/prices/v3/base-rates/search \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "originZIPCode": "22407",
    "destinationZIPCode": "10014",
    "weight": 5,
    "length": 12,
    "width": 10,
    "height": 8,
    "mailClass": "PRIORITY_MAIL",
    "priceType": "COMMERCIAL"
  }'
```

#### Create Label
```bash
curl -X POST https://apis-tem.usps.com/labels/v3/label \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "imageInfo": {
      "imageType": "PDF"
    },
    "fromAddress": {
      "streetAddress": "123 Main St",
      "city": "Fredericksburg",
      "state": "VA",
      "ZIPCode": "22407"
    },
    "toAddress": {
      "streetAddress": "456 Park Ave",
      "city": "New York",
      "state": "NY",
      "ZIPCode": "10014"
    },
    "packageDescription": {
      "weight": 5,
      "length": 12,
      "width": 10,
      "height": 8
    },
    "mailClass": "PRIORITY_MAIL"
  }'
```

---

## Conclusion

Building a USPS shipping integration for Odoo v19 is a substantial but achievable project. The new USPS API platform provides robust capabilities for rate calculation, label generation, and tracking. By following this phased approach, the integration can be completed in approximately 3 months with a single experienced developer.

**Key Success Factors**:
1. **Early USPS enrollment**: Start the USPS Ship account enrollment process immediately
2. **Thorough testing**: Use the USPS test environment extensively before production
3. **Incremental development**: Build and test each phase before moving forward
4. **Security focus**: Protect OAuth credentials and customer data throughout
5. **Documentation**: Maintain clear documentation for users and developers

**Expected Benefits**:
- Automated shipping workflow saving 2-5 minutes per order
- Access to commercial USPS rates (5-40% savings vs retail)
- Improved customer experience with tracking and notifications
- Reduced shipping errors through address validation
- Scalable solution for growing businesses

This integration will provide Odoo users with a modern, reliable USPS shipping solution that leverages the latest API technology and adheres to current USPS standards.

---

**Document Version**: 1.0
**Last Updated**: 2025-11-06
**Author**: Claude (Anthropic)
**Status**: Planning Phase
