@echo off
echo Setting up Predictive Scaling System...

REM Check if Python is installed
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Python is not installed or not in PATH
    echo Please install Python 3.8+ from https://python.org
    pause
    exit /b 1
)

REM Create virtual environment
echo Creating virtual environment...
python -m venv predictive_scaling_env
if %errorlevel% neq 0 (
    echo Failed to create virtual environment
    pause
    exit /b 1
)

REM Activate virtual environment
echo Activating virtual environment...
call predictive_scaling_env\Scripts\activate.bat

REM Upgrade pip
echo Upgrading pip...
python -m pip install --upgrade pip

REM Install PyTorch for AMD GPU (ROCm)
echo Installing PyTorch with ROCm support for AMD GPU...
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm5.6

REM Install other requirements
echo Installing other requirements...
pip install -r requirements.txt

REM Check if Ollama is running
echo Checking Ollama connection...
curl -s http://localhost:11434/api/version >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo Ollama is not running!
    echo Please:
    echo 1. Install Ollama from https://ollama.ai
    echo 2. Run: ollama serve
    echo 3. Install a model: ollama pull mistral
    echo.
    pause
    exit /b 1
)

REM Check if mistral model is available
echo Checking for Mistral model...
ollama list | findstr mistral >nul 2>&1
if %errorlevel% neq 0 (
    echo Installing Mistral model...
    ollama pull mistral
    if %errorlevel% neq 0 (
        echo Failed to install Mistral model
        echo Please run: ollama pull mistral
        pause
        exit /b 1
    )
)

echo.
echo ✅ Setup complete!
echo.
echo To run the predictive scaler:
echo 1. Activate environment: predictive_scaling_env\Scripts\activate.bat
echo 2. Run analysis: python predictive_scaler.py
echo.
echo Make sure you have training data in ./ml_training_data/
echo You can generate this data using fetch_metrics.py
echo.
pause