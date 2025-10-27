# ============================================================================
# MAKEFILE - Bank Marketing DBT Project
# ============================================================================
# Comandos útiles para desarrollo y operación del proyecto.
#
# Uso:
#   make help          - Mostrar ayuda
#   make setup         - Configuración inicial completa
#   make run           - Ejecutar modelos DBT
#   make test          - Ejecutar tests
#   make docs          - Generar y servir documentación
#
# ============================================================================

.PHONY: help setup install-deps load-data dbt-deps run test build docs clean lint format

# Variables
PYTHON := python3
PIP := pip
DBT := dbt
SQLFLUFF := sqlfluff
PROJECT_DIR := dbt_project
DATA_LOADING_DIR := data_loading

# GCP Configuration (override with environment variables or command line)
PROJECT_ID ?= your-gcp-project-id
DATASET ?= bank_marketing_dev

# Default target
.DEFAULT_GOAL := help

# ============================================================================
# HELP
# ============================================================================

help: ## Mostrar esta ayuda
	@echo "╔════════════════════════════════════════════════════════════════╗"
	@echo "║         Bank Marketing DBT Project - Makefile                  ║"
	@echo "╚════════════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "Comandos disponibles:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""

# ============================================================================
# SETUP & INSTALLATION
# ============================================================================

setup: ## Configuración inicial completa del proyecto
	@echo "🚀 Iniciando configuración completa..."
	@$(MAKE) install-deps
	@$(MAKE) dbt-deps
	@echo "✅ Configuración completada!"

install-deps: ## Instalar dependencias de Python
	@echo "📦 Instalando dependencias de Python..."
	@$(PIP) install --upgrade pip
	@$(PIP) install dbt-core==1.7.9
	@$(PIP) install dbt-bigquery==1.7.9
	@$(PIP) install sqlfluff==2.3.5
	@cd $(DATA_LOADING_DIR) && $(PIP) install -r requirements.txt
	@echo "✅ Dependencias instaladas"

dbt-deps: ## Instalar paquetes DBT (dbt-utils, etc.)
	@echo "📚 Instalando paquetes DBT..."
	@cd $(PROJECT_DIR) && $(DBT) deps
	@echo "✅ Paquetes DBT instalados"

# ============================================================================
# DATA LOADING
# ============================================================================

load-data: ## Cargar datos raw a BigQuery
	@echo "📥 Cargando datos a BigQuery..."
	@cd $(DATA_LOADING_DIR) && \
		$(PYTHON) load_to_bigquery.py \
			--project-id $(PROJECT_ID) \
			--dataset $(DATASET)
	@echo "✅ Datos cargados"

load-data-dry-run: ## Dry-run de carga de datos (sin cargar realmente)
	@echo "🔍 Validando datos (dry-run)..."
	@cd $(DATA_LOADING_DIR) && \
		$(PYTHON) load_to_bigquery.py \
			--project-id $(PROJECT_ID) \
			--dataset $(DATASET) \
			--dry-run
	@echo "✅ Validación completada"

# ============================================================================
# DBT OPERATIONS
# ============================================================================

debug: ## Verificar configuración de DBT
	@echo "🔍 Verificando configuración DBT..."
	@cd $(PROJECT_DIR) && $(DBT) debug

compile: ## Compilar modelos DBT (sin ejecutar)
	@echo "🔨 Compilando modelos DBT..."
	@cd $(PROJECT_DIR) && $(DBT) compile

run: ## Ejecutar todos los modelos DBT
	@echo "🏃 Ejecutando modelos DBT..."
	@cd $(PROJECT_DIR) && $(DBT) run

run-staging: ## Ejecutar solo modelos staging
	@echo "🏃 Ejecutando modelos staging..."
	@cd $(PROJECT_DIR) && $(DBT) run --select staging_bank_marketing

run-marts: ## Ejecutar solo modelos marts
	@echo "🏃 Ejecutando modelos marts..."
	@cd $(PROJECT_DIR) && $(DBT) run --select kpi_bank_marketing

test: ## Ejecutar todos los tests DBT
	@echo "🧪 Ejecutando tests..."
	@cd $(PROJECT_DIR) && $(DBT) test

test-store-failures: ## Ejecutar tests y guardar fallos en BigQuery
	@echo "🧪 Ejecutando tests (guardando fallos)..."
	@cd $(PROJECT_DIR) && $(DBT) test --store-failures

build: ## Build completo (run + test)
	@echo "🏗️  Ejecutando build completo..."
	@cd $(PROJECT_DIR) && $(DBT) build

freshness: ## Verificar frescura de datos source
	@echo "📅 Verificando frescura de datos..."
	@cd $(PROJECT_DIR) && $(DBT) source freshness

# ============================================================================
# DOCUMENTATION
# ============================================================================

docs: ## Generar documentación DBT
	@echo "📖 Generando documentación..."
	@cd $(PROJECT_DIR) && $(DBT) docs generate
	@echo "✅ Documentación generada en $(PROJECT_DIR)/target/"

docs-serve: ## Generar y servir documentación (abre navegador)
	@echo "📖 Sirviendo documentación en http://localhost:8080..."
	@cd $(PROJECT_DIR) && $(DBT) docs generate && $(DBT) docs serve

# ============================================================================
# CODE QUALITY
# ============================================================================

lint: ## Lint SQL con SQLFluff
	@echo "🔍 Linting SQL code..."
	@cd $(PROJECT_DIR) && $(SQLFLUFF) lint models/ tests/

lint-fix: ## Auto-fix problemas de linting
	@echo "🔧 Auto-fixing SQL code..."
	@cd $(PROJECT_DIR) && $(SQLFLUFF) fix models/ tests/

format: ## Formatear código SQL
	@echo "✨ Formateando código SQL..."
	@cd $(PROJECT_DIR) && $(SQLFLUFF) format models/ tests/

# ============================================================================
# CLEANING
# ============================================================================

clean: ## Limpiar archivos generados
	@echo "🧹 Limpiando archivos generados..."
	@rm -rf $(PROJECT_DIR)/target/
	@rm -rf $(PROJECT_DIR)/dbt_packages/
	@rm -rf $(PROJECT_DIR)/logs/
	@find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.pyc" -delete
	@echo "✅ Limpieza completada"

clean-all: clean ## Limpieza profunda (incluye dependencias)
	@echo "🧹 Limpieza profunda..."
	@rm -rf venv/
	@rm -rf .pytest_cache/
	@rm -rf .coverage
	@echo "✅ Limpieza profunda completada"

# ============================================================================
# DEVELOPMENT HELPERS
# ============================================================================

shell: ## Abrir shell de Python con context del proyecto
	@echo "🐍 Abriendo Python shell..."
	@$(PYTHON)

validate: lint test ## Validación completa (lint + test)
	@echo "✅ Validación completada"

ci: ## Simular pipeline CI (compilar, lint, test)
	@echo "🔄 Simulando pipeline CI..."
	@$(MAKE) compile
	@$(MAKE) lint
	@$(MAKE) test
	@echo "✅ Pipeline CI completado"

# ============================================================================
# DEPLOYMENT
# ============================================================================

deploy-staging: ## Deploy a ambiente staging
	@echo "🚀 Deploying to staging..."
	@cd $(PROJECT_DIR) && $(DBT) run --target staging
	@cd $(PROJECT_DIR) && $(DBT) test --target staging
	@echo "✅ Deploy a staging completado"

deploy-prod: ## Deploy a producción
	@echo "🚀 Deploying to production..."
	@cd $(PROJECT_DIR) && $(DBT) source freshness --target prod
	@cd $(PROJECT_DIR) && $(DBT) run --target prod
	@cd $(PROJECT_DIR) && $(DBT) test --target prod --store-failures
	@echo "✅ Deploy a producción completado"

# ============================================================================
# PROJECT INFO
# ============================================================================

info: ## Mostrar información del proyecto
	@echo "╔════════════════════════════════════════════════════════════════╗"
	@echo "║              Bank Marketing DBT Project Info                   ║"
	@echo "╚════════════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "📊 Modelos:"
	@cd $(PROJECT_DIR) && $(DBT) ls --resource-type model | wc -l | xargs echo "  Total:"
	@echo ""
	@echo "🧪 Tests:"
	@cd $(PROJECT_DIR) && $(DBT) ls --resource-type test | wc -l | xargs echo "  Total:"
	@echo ""
	@echo "🔧 Macros:"
	@cd $(PROJECT_DIR) && $(DBT) ls --resource-type macro | wc -l | xargs echo "  Total:"
	@echo ""
	@echo "📦 Paquetes instalados:"
	@cd $(PROJECT_DIR) && ls -1 dbt_packages/ 2>/dev/null | head -5 || echo "  Ninguno"
	@echo ""

version: ## Mostrar versiones de herramientas
	@echo "Versiones instaladas:"
	@echo "  Python: $$($(PYTHON) --version)"
	@echo "  DBT: $$(cd $(PROJECT_DIR) && $(DBT) --version | head -1)"
	@echo "  SQLFluff: $$($(SQLFLUFF) --version)"

# ============================================================================
# QUICK ACTIONS
# ============================================================================

quick-run: ## Quick run (staging + marts sin tests)
	@echo "⚡ Quick run..."
	@cd $(PROJECT_DIR) && $(DBT) run --select staging_bank_marketing kpi_bank_marketing
	@echo "✅ Quick run completado"

full-refresh: ## Full refresh de todos los modelos
	@echo "🔄 Full refresh..."
	@cd $(PROJECT_DIR) && $(DBT) run --full-refresh
	@echo "✅ Full refresh completado"

# ============================================================================
# EJEMPLOS DE USO CON VARIABLES
# ============================================================================
#
# Usar variables:
#   make load-data PROJECT_ID=my-project DATASET=raw_data
#   make deploy-staging
#   make deploy-prod
#
# Variables disponibles:
#   PROJECT_ID  - GCP Project ID
#   DATASET     - BigQuery Dataset name
#
# ============================================================================
