#!/bin/bash
# setup.sh - Automated setup script for CallTracer test environment

set -e

echo "======================================"
echo "CallTracer Testing Suite Setup"
echo "======================================"
echo ""

# Check for Python 3
if ! command -v python3 &> /dev/null; then
    echo "❌ Error: Python 3 is not installed"
    echo "Please install Python 3.10+ and try again"
    exit 1
fi

PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
echo "✓ Found Python $PYTHON_VERSION"

# Check for required tools
echo ""
echo "Checking required tools..."

if ! command -v kurtosis &> /dev/null; then
    echo "❌ Error: Kurtosis is not installed"
    echo "Install from: https://docs.kurtosis.com/install"
    exit 1
fi
echo "✓ Kurtosis installed: $(kurtosis version | head -1)"

if ! command -v forge &> /dev/null; then
    echo "❌ Error: Foundry (forge) is not installed"
    echo "Install from: https://getfoundry.sh/"
    exit 1
fi
echo "✓ Foundry installed: $(forge --version | head -1)"

# Initialize git submodules
echo ""
echo "Initializing git submodules..."
if [ -f .gitmodules ]; then
    git submodule update --init --recursive
    echo "✓ Submodules initialized"
else
    echo "⚠ No .gitmodules found, skipping"
fi

# Create virtual environment
echo ""
echo "Creating Python virtual environment..."
if [ -d "venv" ]; then
    echo "⚠ Virtual environment already exists"
    read -p "Do you want to recreate it? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf venv
        python3 -m venv venv
        echo "✓ Virtual environment recreated"
    else
        echo "Using existing virtual environment"
    fi
else
    python3 -m venv venv
    echo "✓ Virtual environment created"
fi

# Activate virtual environment and install dependencies
echo ""
echo "Installing Python dependencies..."

# Detect OS for activation command
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    # Windows
    source venv/Scripts/activate
else
    # Linux/macOS
    source venv/bin/activate
fi

pip install --upgrade pip
pip install -r requirements.txt

echo "✓ Dependencies installed"

# Summary
echo ""
echo "======================================"
echo "Setup Complete!"
echo "======================================"
echo ""
echo "To activate the virtual environment:"
echo ""
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    echo "  venv\\Scripts\\activate"
else
    echo "  source venv/bin/activate"
fi
echo ""
echo "Then you can run the tests:"
echo ""
echo "  python kurtosis_manager.py start"
echo "  python call_tracer_tests.py"
echo "  python kurtosis_manager.py stop"
echo ""
echo "See README.md for more information."
