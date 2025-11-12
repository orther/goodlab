# Age verification gate for Research Relay eCommerce
# Implements session-based age verification modal via nginx + Lua
{
  config,
  pkgs,
  lib,
  ...
}: let
  # Age gate HTML page
  ageGateHtml = pkgs.writeText "age-gate.html" ''
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Age Verification Required - Research Relay</title>
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          min-height: 100vh;
          display: flex;
          align-items: center;
          justify-content: center;
          padding: 20px;
        }
        .age-gate {
          background: white;
          border-radius: 20px;
          box-shadow: 0 20px 60px rgba(0,0,0,0.3);
          max-width: 500px;
          width: 100%;
          padding: 40px;
          text-align: center;
        }
        .logo {
          font-size: 32px;
          font-weight: bold;
          color: #667eea;
          margin-bottom: 20px;
        }
        h1 {
          font-size: 24px;
          color: #2d3748;
          margin-bottom: 15px;
        }
        .notice {
          color: #718096;
          font-size: 14px;
          line-height: 1.6;
          margin-bottom: 30px;
        }
        .warning {
          background: #fff5f5;
          border: 2px solid #fc8181;
          border-radius: 10px;
          padding: 15px;
          margin-bottom: 30px;
          color: #c53030;
          font-size: 13px;
          font-weight: 500;
        }
        form {
          display: flex;
          flex-direction: column;
          gap: 20px;
        }
        .form-group {
          text-align: left;
        }
        label {
          display: block;
          font-weight: 600;
          color: #2d3748;
          margin-bottom: 8px;
          font-size: 14px;
        }
        select {
          width: 100%;
          padding: 12px 16px;
          border: 2px solid #e2e8f0;
          border-radius: 10px;
          font-size: 16px;
          background: white;
          cursor: pointer;
          transition: border-color 0.2s;
        }
        select:focus {
          outline: none;
          border-color: #667eea;
        }
        .checkbox-group {
          display: flex;
          align-items: flex-start;
          gap: 10px;
          text-align: left;
        }
        input[type="checkbox"] {
          margin-top: 4px;
          width: 20px;
          height: 20px;
          cursor: pointer;
        }
        .checkbox-group label {
          margin-bottom: 0;
          font-weight: 400;
          cursor: pointer;
        }
        button {
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          color: white;
          border: none;
          padding: 15px 32px;
          border-radius: 10px;
          font-size: 16px;
          font-weight: 600;
          cursor: pointer;
          transition: transform 0.2s, box-shadow 0.2s;
        }
        button:hover {
          transform: translateY(-2px);
          box-shadow: 0 10px 20px rgba(102, 126, 234, 0.4);
        }
        button:active {
          transform: translateY(0);
        }
        button:disabled {
          opacity: 0.5;
          cursor: not-allowed;
          transform: none;
        }
        .footer {
          margin-top: 30px;
          padding-top: 20px;
          border-top: 1px solid #e2e8f0;
          color: #a0aec0;
          font-size: 12px;
        }
      </style>
    </head>
    <body>
      <div class="age-gate">
        <div class="logo">🧬 Research Relay</div>
        <h1>Age Verification Required</h1>
        <p class="notice">
          This website offers research peptides for scientific and educational purposes only.
          You must be 18 years or older to access this site.
        </p>
        <div class="warning">
          ⚠️ These products are not for human consumption. Research use only.
        </div>

        <form action="/age-verify" method="POST" id="ageForm">
          <div class="form-group">
            <label for="birth_year">Year of Birth</label>
            <select name="birth_year" id="birth_year" required>
              <option value="">Select your birth year</option>
            </select>
          </div>

          <div class="checkbox-group">
            <input type="checkbox" id="confirm" name="confirm" value="yes" required>
            <label for="confirm">
              I confirm that I am at least 18 years old and understand these products are for research purposes only.
            </label>
          </div>

          <button type="submit" id="submitBtn" disabled>Enter Site</button>
        </form>

        <div class="footer">
          By entering, you agree to our Terms of Service and Privacy Policy
        </div>
      </div>

      <script>
        // Populate birth year dropdown
        const yearSelect = document.getElementById('birth_year');
        const currentYear = new Date().getFullYear();
        for (let year = currentYear - 18; year >= currentYear - 100; year--) {
          const option = document.createElement('option');
          option.value = year;
          option.textContent = year;
          yearSelect.appendChild(option);
        }

        // Enable submit button only when both fields are filled
        const checkbox = document.getElementById('confirm');
        const submitBtn = document.getElementById('submitBtn');

        function checkFormValidity() {
          const isValid = yearSelect.value && checkbox.checked;
          submitBtn.disabled = !isValid;
        }

        yearSelect.addEventListener('change', checkFormValidity);
        checkbox.addEventListener('change', checkFormValidity);
      </script>
    </body>
    </html>
  '';

  # Age restricted page (for under 18)
  ageRestrictedHtml = pkgs.writeText "age-restricted.html" ''
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Access Restricted - Research Relay</title>
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
          background: linear-gradient(135deg, #fc8181 0%, #f56565 100%);
          min-height: 100vh;
          display: flex;
          align-items: center;
          justify-content: center;
          padding: 20px;
        }
        .message {
          background: white;
          border-radius: 20px;
          box-shadow: 0 20px 60px rgba(0,0,0,0.3);
          max-width: 500px;
          width: 100%;
          padding: 40px;
          text-align: center;
        }
        .icon { font-size: 64px; margin-bottom: 20px; }
        h1 { font-size: 24px; color: #2d3748; margin-bottom: 15px; }
        p { color: #718096; line-height: 1.6; }
      </style>
    </head>
    <body>
      <div class="message">
        <div class="icon">🚫</div>
        <h1>Access Restricted</h1>
        <p>You must be at least 18 years old to access this website.</p>
      </div>
    </body>
    </html>
  '';
in {
  # Module option (define first)
  options.services.researchRelay.ageGate = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false; # Disabled by default - requires nginx Lua support
      description = lib.mdDoc "Enable age verification gate for the eCommerce website (requires nginx with Lua module)";
    };
  };

  # Age gate implementation
  # NOTE: This module is currently disabled pending nginx Lua module integration
  # The age gate functionality can be implemented via:
  # 1. Odoo website module with age verification
  # 2. Cloudflare Worker script
  # 3. Custom nginx module with proper Lua support
  #
  # Uncomment and configure nginx additionalModules when ready:
  # services.nginx.additionalModules = [ (pkgs.nginxModules.lua or pkgs.nginx.modules.lua) ];

  config = lib.mkIf config.services.researchRelay.ageGate.enable {
    # Age gate static files - served directly by nginx
    systemd.tmpfiles.rules = [
      "d /var/www/age-gate 0755 nginx nginx -"
    ];

    # Copy HTML files to web directory
    system.activationScripts.age-gate-setup = ''
      mkdir -p /var/www/age-gate
      cat ${ageGateHtml} > /var/www/age-gate/age-gate.html
      cat ${ageRestrictedHtml} > /var/www/age-gate/age-restricted.html
      chown -R nginx:nginx /var/www/age-gate
    '';

    # Note: Nginx configuration for age gate is placeholder
    # Requires proper Lua module integration for production use
    # See AGE_GATE.md for implementation options
  };
}
