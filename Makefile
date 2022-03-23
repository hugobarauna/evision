PRIV_DIR = $(MIX_APP_PATH)/priv
EVISION_SO = $(PRIV_DIR)/evision.so
C_SRC = $(shell pwd)/c_src
PY_SRC = $(shell pwd)/py_src
LIB_SRC = $(shell pwd)/lib
ifdef CMAKE_TOOLCHAIN_FILE
	CMAKE_CONFIGURE_FLAGS=-D CMAKE_TOOLCHAIN_FILE="$(CMAKE_TOOLCHAIN_FILE)"
endif

# OpenCV
OPENCV_USE_GIT_HEAD ?= false
OPENCV_GIT_REPO ?= "https://github.com/opencv/opencv.git"
OPENCV_VER ?= 4.5.5
ifneq ($(OPENCV_USE_GIT_HEAD), false)
	OPENCV_VER=$(OPENCV_USE_GIT_BRANCH)
endif
OPENCV_CACHE_DIR = $(shell pwd)/3rd_party/cache
OPENCV_SOURCE_ZIP = $(OPENCV_CACHE_DIR)/opencv-$(OPENCV_VER).zip
OPENCV_ROOT_DIR = $(shell pwd)/3rd_party/opencv
OPENCV_DIR = $(OPENCV_ROOT_DIR)/opencv-$(OPENCV_VER)
OPENCV_CONFIGURATION_PRIVATE_HPP = $(OPENCV_DIR)/modules/core/include/opencv2/core/utils/configuration.private.hpp
PYTHON3_EXECUTABLE = $(shell which python3)
CMAKE_OPENCV_BUILD_DIR = $(MIX_APP_PATH)/cmake_opencv_$(OPENCV_VER)
CMAKE_OPENCV_MODULE_SELECTION ?= -D BUILD_opencv_python2=OFF \
-D BUILD_opencv_python3=OFF \
-D BUILD_opencv_gapi=OFF
CMAKE_OPENCV_IMG_CODER_SELECTION ?= -D BUILD_PNG=ON \
-D BUILD_JPEG=ON \
-D BUILD_TIFF=ON \
-D BUILD_WEBP=ON \
-D BUILD_OPENJPEG=ON \
-D BUILD_JASPER=ON \
-D BUILD_OPENEXR=ON
CMAKE_OPENCV_OPTIONS ?= ""
CMAKE_OPTIONS ?= $(CMAKE_OPENCV_MODULE_SELECTION) $(CMAKE_OPENCV_IMG_CODER_SELECTION) $(CMAKE_OPENCV_OPTIONS)
CMAKE_OPTIONS += $(CMAKE_CONFIGURE_FLAGS)
ENABLED_CV_MODULES ?= ""

# evision
HEADERS_TXT = $(CMAKE_OPENCV_BUILD_DIR)/modules/python_bindings_generator/headers.txt
CONFIGURATION_PRIVATE_HPP = $(C_SRC)/configuration.private.hpp
GENERATED_ELIXIR_SRC_DIR = $(LIB_SRC)/generated
CMAKE_EVISION_BUILD_DIR = $(MIX_APP_PATH)/cmake_evision
MAKE_BUILD_FLAGS ?= "-j1"
EVISION_PREFER_PRECOMPILED ?= false
EVISION_PRECOMPILED_VERSION ?= "0.1.0-dev"

.DEFAULT_GLOBAL := build

build: $(EVISION_SO)

$(OPENCV_CONFIGURATION_PRIVATE_HPP):
	@ if [ "$(EVISION_PREFER_PRECOMPILE)" -ne "true" ]; then \
   		if [ ! -e "$(OPENCV_CONFIGURATION_PRIVATE_HPP)" ]; then \
			if [ "$(OPENCV_USE_GIT_HEAD)" = "false" ]; then \
				echo "using $(OPENCV_VER)" ; \
			else \
		  		rm -rf "$(OPENCV_DIR)" ; \
				git clone --branch=$(OPENCV_USE_GIT_BRANCH) --depth=1 $(OPENCV_GIT_REPO) "$(OPENCV_DIR)" ; \
			fi \
		fi \
	fi

$(CONFIGURATION_PRIVATE_HPP): $(OPENCV_CONFIGURATION_PRIVATE_HPP)
	@ if [ "$(EVISION_PREFER_PRECOMPILE)" -ne "true" ]; then \
   		cp "$(OPENCV_CONFIGURATION_PRIVATE_HPP)" "$(CONFIGURATION_PRIVATE_HPP)" ; \
	fi

$(HEADERS_TXT): $(CONFIGURATION_PRIVATE_HPP)
	@ if [ "$(EVISION_PREFER_PRECOMPILE)" -ne "true" ]; then \
		sh -c "OPENCV_DIR=$(OPENCV_DIR) $(shell pwd)/patches/$(OPENCV_VER)/apply_patch.sh || true" ; \
		mkdir -p $(CMAKE_OPENCV_BUILD_DIR) && \
		cd $(CMAKE_OPENCV_BUILD_DIR) && \
		cmake -D CMAKE_BUILD_TYPE=RELEASE \
			-D CMAKE_INSTALL_PREFIX=$(PRIV_DIR) \
			-D PYTHON3_EXECUTABLE=$(PYTHON3_EXECUTABLE) \
			-D INSTALL_PYTHON_EXAMPLES=OFF \
			-D INSTALL_C_EXAMPLES=OFF \
			-D BUILD_EXAMPLES=OFF \
			-D BUILD_TESTS=OFF \
			-D OPENCV_ENABLE_NONFREE=OFF \
			-D OPENCV_GENERATE_PKGCONFIG=ON \
			-D OPENCV_PC_FILE_NAME=opencv4.pc \
			-D BUILD_ZLIB=ON \
			-D BUILD_opencv_gapi=OFF \
			-D CMAKE_C_FLAGS=-DPNG_ARM_NEON_OPT=0 \
			-D CMAKE_CXX_FLAGS=-DPNG_ARM_NEON_OPT=0 \
			-D CMAKE_TOOLCHAIN_FILE="$(TOOLCHAIN_FILE)" \
			$(CMAKE_OPTIONS) $(OPENCV_DIR) && \
		make "$(MAKE_BUILD_FLAGS)" && \
		cd $(CMAKE_OPENCV_BUILD_DIR) && make install && \
		cp "$(HEADERS_TXT)" "$(C_SRC)/headers.txt" ; \
	fi

$(EVISION_SO): $(HEADERS_TXT)
	@ mkdir -p $(PRIV_DIR)
	@ mkdir -p $(CMAKE_EVISION_BUILD_DIR)
	@ mkdir -p "$(GENERATED_ELIXIR_SRC_DIR)"
	@ cd "$(CMAKE_EVISION_BUILD_DIR)" && \
		{ cmake -D C_SRC="$(C_SRC)" \
		  -D CMAKE_TOOLCHAIN_FILE="$(TOOLCHAIN_FILE)" \
		  -D GENERATED_ELIXIR_SRC_DIR="$(GENERATED_ELIXIR_SRC_DIR)" \
		  -D PY_SRC="$(PY_SRC)" \
		  -D PRIV_DIR="$(PRIV_DIR)" \
		  -D ERTS_INCLUDE_DIR="$(ERTS_INCLUDE_DIR)" \
		  -D ENABLED_CV_MODULES=$(ENABLED_CV_MODULES) \
		  -D EVISION_PREFER_PRECOMPILED="$(EVISION_PREFER_PRECOMPILED)" \
		  -D EVISION_PRECOMPILED_VERSION="$(EVISION_PRECOMPILED_VERSION)" \
		  $(CMAKE_CONFIGURE_FLAGS) "$(shell pwd)" && \
		  make "$(MAKE_BUILD_FLAGS)" \
		  || { echo "\033[0;31mincomplete build of OpenCV found in '$(CMAKE_OPENCV_BUILD_DIR)', please delete that directory and retry\033[0m" && exit 1 ; } ; } \
		&& if [ "${EVISION_PREFER_PRECOMPILED}" != "true" ]; then \
			cp "$(CMAKE_EVISION_BUILD_DIR)/evision.so" "$(EVISION_SO)" ; \
		else \
			echo "copy from precompiled package" ; \
		fi
