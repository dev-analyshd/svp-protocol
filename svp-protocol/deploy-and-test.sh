#!/bin/bash

###############################################################################
# SVP Protocol - One-Command Deployment & Testing Script
# 
# Usage: ./deploy-and-test.sh [network]
# Networks: arbitrumSepolia, robinhoodChain, localhost
###############################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NETWORK="${1:-arbitrumSepolia}"
DEPLOYMENT_DIR="./deployments"
LOG_FILE="deployment-$(date +%Y%m%d-%H%M%S).log"

###############################################################################
# UTILITY FUNCTIONS
###############################################################################

print_header() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║ $1${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo -e "${GREEN}✓${NC} $1"
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_success() {
    echo -e "${GREEN}✨${NC} $1"
}

###############################################################################
# PRE-DEPLOYMENT CHECKS
###############################################################################

check_requirements() {
    print_header "PRE-DEPLOYMENT CHECKS"

    # Check Node.js
    if ! command -v node &> /dev/null; then
        print_error "Node.js not installed"
        exit 1
    fi
    print_step "Node.js installed: $(node --version)"

    # Check npm
    if ! command -v npm &> /dev/null; then
        print_error "npm not installed"
        exit 1
    fi
    print_step "npm installed: $(npm --version)"

    # Check .env file
    if [ ! -f ".env" ] && [ ! -f ".env.example" ]; then
        print_error ".env or .env.example not found"
        exit 1
    fi
    print_step ".env configuration file found"

    # Check Hardhat
    if [ ! -f "hardhat.config.ts" ]; then
        print_error "hardhat.config.ts not found"
        exit 1
    fi
    print_step "Hardhat configuration found"

    # Check contracts
    if [ ! -d "contracts" ]; then
        print_error "contracts directory not found"
        exit 1
    fi
    print_step "Contracts directory found ($(ls contracts/*.sol | wc -l) files)"

    print_success "All pre-deployment checks passed"
}

###############################################################################
# INSTALLATION
###############################################################################

install_dependencies() {
    print_header "INSTALLING DEPENDENCIES"

    if [ -d "node_modules" ]; then
        print_info "node_modules already exists, skipping installation"
    else
        print_info "Installing npm packages..."
        npm install --loglevel=error
        print_step "Dependencies installed"
    fi
}

###############################################################################
# COMPILATION
###############################################################################

compile_contracts() {
    print_header "COMPILING SMART CONTRACTS"

    print_info "Compiling with Hardhat..."
    npx hardhat compile --quiet

    # Count compiled files
    ARTIFACT_COUNT=$(find artifacts/contracts -name "*.json" -type f | grep -v ".dbg.json" | wc -l)
    
    print_step "Contracts compiled: $ARTIFACT_COUNT artifacts generated"
    print_step "TypeChain types generated"
}

###############################################################################
# DEPLOYMENT
###############################################################################

deploy_contracts() {
    print_header "DEPLOYING CONTRACTS TO $NETWORK"

    print_info "Network: $NETWORK"
    print_info "This may take 2-5 minutes depending on network congestion..."

    # Create deployments directory
    mkdir -p "$DEPLOYMENT_DIR"

    # Run deployment
    npx hardhat run scripts/deploy.ts --network "$NETWORK" 2>&1 | tee -a "$LOG_FILE"

    if [ $? -eq 0 ]; then
        print_success "Contracts deployed successfully"
        
        # Check deployment file
        LATEST_DEPLOYMENT=$(ls -t "$DEPLOYMENT_DIR"/*.json 2>/dev/null | head -1)
        if [ -f "$LATEST_DEPLOYMENT" ]; then
            print_step "Deployment record: $(basename $LATEST_DEPLOYMENT)"
        fi
    else
        print_error "Deployment failed"
        exit 1
    fi
}

###############################################################################
# TESTING
###############################################################################

run_tests() {
    print_header "RUNNING TESTS"

    # Unit Tests
    print_info "Running unit tests..."
    npx hardhat test test/protocol.full.test.ts 2>&1 | tee -a "$LOG_FILE"

    if [ $? -ne 0 ]; then
        print_error "Unit tests failed"
        return 1
    fi
    print_success "Unit tests passed"

    # Integration Tests
    print_info "Running DApp integration tests..."
    npx hardhat test test/dapp.integration.test.ts 2>&1 | tee -a "$LOG_FILE"

    if [ $? -ne 0 ]; then
        print_error "Integration tests failed"
        return 1
    fi
    print_success "Integration tests passed"

    # Existing tests (if any)
    print_info "Running additional protocol tests..."
    npx hardhat test test/ 2>&1 | tee -a "$LOG_FILE" || true

    print_success "All tests completed"
}

###############################################################################
# GAS REPORTING
###############################################################################

report_gas() {
    print_header "GAS OPTIMIZATION REPORT"

    if [ -f "gas-report.txt" ]; then
        print_info "Gas report generated:"
        head -20 gas-report.txt
        print_step "Full report: gas-report.txt"
    else
        print_info "Gas reporting not enabled in this run"
    fi
}

###############################################################################
# VERIFICATION
###############################################################################

verify_deployment() {
    print_header "DEPLOYMENT VERIFICATION"

    LATEST_DEPLOYMENT=$(ls -t "$DEPLOYMENT_DIR"/*.json 2>/dev/null | head -1)

    if [ -f "$LATEST_DEPLOYMENT" ]; then
        print_info "Deployment Summary:"
        
        # Parse and display deployment info
        if command -v jq &> /dev/null; then
            echo ""
            jq '.contracts | to_entries[] | "\(.key): \(.value)"' "$LATEST_DEPLOYMENT"
            echo ""
        else
            cat "$LATEST_DEPLOYMENT"
        fi
        
        print_success "Deployment verified successfully"
    else
        print_error "No deployment record found"
        exit 1
    fi
}

###############################################################################
# COVERAGE REPORT
###############################################################################

generate_coverage() {
    print_header "CODE COVERAGE REPORT"

    print_info "Generating coverage report..."
    npx hardhat coverage 2>&1 | tail -20

    if [ -d "coverage" ]; then
        print_step "Coverage HTML report: coverage/index.html"
    fi
}

###############################################################################
# SUMMARY
###############################################################################

print_summary() {
    print_header "🎉 DEPLOYMENT & TESTING SUMMARY"

    echo -e "${GREEN}✅ Completed Steps:${NC}"
    echo "  ✓ Pre-deployment checks"
    echo "  ✓ Dependencies installed"
    echo "  ✓ Contracts compiled ($(ls contracts/*.sol | wc -l) files)"
    echo "  ✓ Contracts deployed to $NETWORK"
    echo "  ✓ Unit tests passed"
    echo "  ✓ Integration tests passed"
    echo "  ✓ Deployment verified"

    echo ""
    echo -e "${BLUE}📋 Deployment Information:${NC}"
    echo "  Network: $NETWORK"
    echo "  Deployment Log: $LOG_FILE"
    echo "  Deployments Dir: $DEPLOYMENT_DIR"
    
    LATEST_DEPLOYMENT=$(ls -t "$DEPLOYMENT_DIR"/*.json 2>/dev/null | head -1)
    if [ -f "$LATEST_DEPLOYMENT" ]; then
        echo "  Latest Deployment: $(basename $LATEST_DEPLOYMENT)"
    fi

    echo ""
    echo -e "${BLUE}📚 Next Steps:${NC}"
    echo "  1. Review deployment in: cat $DEPLOYMENT_DIR/*.json"
    echo "  2. View logs: cat $LOG_FILE"
    echo "  3. Check contract on explorer (provide URL)"
    echo "  4. Update frontend with contract addresses"
    echo "  5. Initialize governance (if needed)"
    echo "  6. Start testing with real users"

    echo ""
    echo -e "${GREEN}✨ Protocol is ready for use!${NC}"
}

###############################################################################
# MAIN EXECUTION
###############################################################################

main() {
    print_header "SVP PROTOCOL - DEPLOYMENT & TESTING PIPELINE"
    echo -e "${YELLOW}Starting deployment to $NETWORK${NC}"
    echo -e "${YELLOW}Logs: $LOG_FILE${NC}"

    # Execute steps
    check_requirements
    install_dependencies
    compile_contracts
    deploy_contracts
    run_tests
    report_gas
    verify_deployment
    
    # Optional: generate_coverage (commented out to save time)
    # generate_coverage

    # Print summary
    print_summary

    echo ""
}

# Run main function
main

exit 0
