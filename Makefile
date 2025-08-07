include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-openlistui

# 自动版本管理系统
PKG_VERSION_BASE:=1.0
GITHUB_REPO:=drfccv/luci-app-openlistui

# 动态版本管理
PKG_VERSION:=$(shell \
	if [ -n "$$CUSTOM_VERSION" ]; then \
		echo "$$CUSTOM_VERSION"; \
	else \
		latest_version=$$(curl -s "https://api.github.com/repos/$(GITHUB_REPO)/releases/latest" 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"tag_name":\s*"([^"]+)".*/\1/' | sed 's/^v//'); \
		if [ -n "$$latest_version" ]; then \
			github_base=$$(echo "$$latest_version" | cut -d'.' -f1-2); \
			if [ "$$github_base" = "$(PKG_VERSION_BASE)" ]; then \
				github_patch=$$(echo "$$latest_version" | cut -d'.' -f3); \
				next_patch=$$((github_patch + 1)); \
				echo "$(PKG_VERSION_BASE).$$next_patch"; \
			else \
				patch_version=1; \
				if [ -d .git ]; then \
					patch_version=$$(git rev-list --count HEAD 2>/dev/null || echo "1"); \
				fi; \
				echo "$(PKG_VERSION_BASE).$$patch_version"; \
			fi; \
		else \
			patch_version=1; \
			if [ -d .git ]; then \
				patch_version=$$(git rev-list --count HEAD 2>/dev/null || echo "1"); \
			fi; \
			echo "$(PKG_VERSION_BASE).$$patch_version"; \
		fi; \
	fi)

# 构建信息
PKG_RELEASE:=$(shell date +%Y%m%d%H%M)
PKG_BUILD_DATE:=$(shell date +%Y-%m-%d\ %H:%M:%S)
PKG_BUILD_HOST:=$(shell whoami 2>/dev/null || echo "unknown")@$(shell hostname 2>/dev/null || echo "unknown")
PKG_GIT_HASH:=$(shell if [ -d .git ]; then git rev-parse --short HEAD 2>/dev/null || echo "unknown"; else echo "unknown"; fi)
PKG_GIT_BRANCH:=$(shell if [ -d .git ]; then git branch --show-current 2>/dev/null || echo "unknown"; else echo "unknown"; fi)
PKG_BUILD_ARCH:=$(shell uname -m 2>/dev/null || echo "unknown")

PKG_LICENSE:=MIT
PKG_MAINTAINER:=Drfccv

include $(INCLUDE_DIR)/package.mk

# 显示构建信息
$(info Building $(PKG_NAME) v$(PKG_VERSION) ($(PKG_BUILD_DATE)))
$(info Git: $(PKG_GIT_HASH) on $(PKG_GIT_BRANCH))
$(info Host: $(PKG_BUILD_HOST))

define Package/luci-app-openlistui
	SECTION:=luci
	CATEGORY:=LuCI
	SUBMENU:=3. Applications
	TITLE:=LuCI Support for OpenList UI
	DEPENDS:=+luci-base +luci-lib-jsonc +luci-lib-nixio +curl +wget +unzip +busybox
	PKGARCH:=all
endef

define Package/luci-app-openlistui/description
	A web interface for managing OpenList file management service
endef

# Conffiles declaration for UCI configuration preservation
define Package/luci-app-openlistui/conffiles
/etc/config/openlistui
endef

# Add a checksum to help with config file detection
define Package/luci-app-openlistui/config_checksum
$(shell md5sum "root/etc/config/openlistui" 2>/dev/null | cut -d' ' -f1 || echo "unknown")
endef

define Package/luci-app-openlistui/postinst
#!/bin/sh
# Standard LuCI cache clearing and service restart
if [ -z "$${IPKG_INSTROOT}" ]; then
	echo "Installing/Upgrading luci-app-openlistui..."
	
	# Detect service state for restoration
	SERVICE_ENABLED=0
	SERVICE_RUNNING=0
	
	if [ -f /tmp/openlistui-upgrade-state ]; then
		echo "Restoring service state from upgrade..."
		. /tmp/openlistui-upgrade-state
		rm -f /tmp/openlistui-upgrade-state
		SERVICE_ENABLED=$${SERVICE_WAS_ENABLED}
		SERVICE_RUNNING=$${SERVICE_WAS_RUNNING}
	elif [ -f /etc/config/openlistui ]; then
		echo "Detecting current service state..."
		if [ -x /etc/init.d/openlistui ]; then
			/etc/init.d/openlistui enabled >/dev/null 2>&1 && SERVICE_ENABLED=1
			/etc/init.d/openlistui running >/dev/null 2>&1 && SERVICE_RUNNING=1
		fi
	else
		echo "Fresh installation detected"
	fi
	
	# Clear LuCI cache
	echo "Clearing LuCI cache..."
	rm -rf /tmp/luci-indexcache /tmp/luci-modulecache/ 2>/dev/null || true
	
	# Rebuild LuCI index
	if [ -x /usr/bin/lua ]; then
		lua -e "require('luci.dispatcher').build_url()" 2>/dev/null || true
	fi
	
	# Configuration is now handled by conffiles mechanism
	# No manual backup/restore needed - opkg handles this automatically
	
	# Restore service state after upgrade
	if [ -x /etc/init.d/openlistui ]; then
		if [ "$${SERVICE_ENABLED}" = "1" ]; then
			/etc/init.d/openlistui enable 2>/dev/null || true
			if [ "$${SERVICE_RUNNING}" = "1" ]; then
				echo "Restarting OpenListUI service after upgrade..."
				/etc/init.d/openlistui restart 2>/dev/null || true
			fi
		fi
	fi
	
	# Ensure killall is available for service management
	if ! command -v killall >/dev/null 2>&1; then
		echo "Warning: killall command not found. Service management may be affected."
	fi
	
	# Restart rpcd and uhttpd to ensure proper LuCI functionality
	echo "Restarting LuCI services..."
	/etc/init.d/rpcd restart 2>/dev/null || true
	/etc/init.d/uhttpd restart 2>/dev/null || true
	
	echo "Installation/upgrade completed successfully"
fi
exit 0
endef

define Package/luci-app-openlistui/prerm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	# Detect if this is an upgrade or removal
	if [ "$${PKG_UPGRADE}" = "1" ]; then
		echo "Upgrading luci-app-openlistui - preserving service state"
		
		# Store current service state for restoration after upgrade
		if [ -x /etc/init.d/openlistui ]; then
			if /etc/init.d/openlistui enabled >/dev/null 2>&1; then
				echo "SERVICE_WAS_ENABLED=1" > /tmp/openlistui-upgrade-state
			else
				echo "SERVICE_WAS_ENABLED=0" > /tmp/openlistui-upgrade-state
			fi
			
			if /etc/init.d/openlistui running >/dev/null 2>&1; then
				echo "SERVICE_WAS_RUNNING=1" >> /tmp/openlistui-upgrade-state
			else
				echo "SERVICE_WAS_RUNNING=0" >> /tmp/openlistui-upgrade-state
			fi
		fi
		
		# Configuration is now handled by conffiles mechanism
		# No manual backup needed - opkg handles this automatically
		
	else
		echo "Removing luci-app-openlistui - stopping service"
		if [ -x /etc/init.d/openlistui ]; then
			/etc/init.d/openlistui disable 2>/dev/null || true
			/etc/init.d/openlistui stop 2>/dev/null || true
		fi
		
		# Clean up temporary files on removal
		rm -f /tmp/openlistui-upgrade-state
	fi
}
endef

define Build/Prepare
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/luci-app-openlistui/install
	# 创建基本目录结构
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/openlistui
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi/openlistui
	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/openlistui
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	
	# 创建详细的版本信息文件
	echo "# OpenList UI Version Information" > $(1)/usr/lib/lua/luci/version-openlistui
	echo "# Generated on $(PKG_BUILD_DATE)" >> $(1)/usr/lib/lua/luci/version-openlistui
	echo "" >> $(1)/usr/lib/lua/luci/version-openlistui
	echo "PKG_NAME=$(PKG_NAME)" >> $(1)/usr/lib/lua/luci/version-openlistui
	echo "PKG_VERSION=$(PKG_VERSION)" >> $(1)/usr/lib/lua/luci/version-openlistui
	echo "PKG_VERSION_BASE=$(PKG_VERSION_BASE)" >> $(1)/usr/lib/lua/luci/version-openlistui
	echo "PKG_VERSION_PATCH=$(PKG_VERSION_PATCH)" >> $(1)/usr/lib/lua/luci/version-openlistui
	echo "PKG_RELEASE=$(PKG_RELEASE)" >> $(1)/usr/lib/lua/luci/version-openlistui
	echo "BUILD_DATE=$(PKG_BUILD_DATE)" >> $(1)/usr/lib/lua/luci/version-openlistui
	echo "BUILD_HOST=$(PKG_BUILD_HOST)" >> $(1)/usr/lib/lua/luci/version-openlistui
	echo "BUILD_ARCH=$(PKG_BUILD_ARCH)" >> $(1)/usr/lib/lua/luci/version-openlistui
	echo "GIT_HASH=$(PKG_GIT_HASH)" >> $(1)/usr/lib/lua/luci/version-openlistui
	echo "GIT_BRANCH=$(PKG_GIT_BRANCH)" >> $(1)/usr/lib/lua/luci/version-openlistui
	
	# 安装控制器文件
	$(INSTALL_DATA) ./luasrc/controller/openlistui.lua $(1)/usr/lib/lua/luci/controller/openlistui.lua
	
	# 安装 CBI 模型文件
	if [ -d "./luasrc/model/cbi/openlistui" ]; then \
		$(INSTALL_DATA) ./luasrc/model/cbi/openlistui/*.lua $(1)/usr/lib/lua/luci/model/cbi/openlistui/ 2>/dev/null || true; \
	fi
	
	# 安装视图文件
	if [ -d "./luasrc/view/openlistui" ]; then \
		$(INSTALL_DATA) ./luasrc/view/openlistui/*.htm $(1)/usr/lib/lua/luci/view/openlistui/ 2>/dev/null || true; \
	fi
	
	# 安装 JavaScript 模块文件 (LuCI2)
	if [ -d "./htdocs/luci-static/resources/view/openlistui" ]; then \
		$(INSTALL_DATA) ./htdocs/luci-static/resources/view/openlistui/*.js $(1)/www/luci-static/resources/view/openlistui/ 2>/dev/null || true; \
	fi
	
	# 安装初始化脚本和配置文件
	$(INSTALL_BIN) ./root/etc/init.d/openlistui $(1)/etc/init.d/openlistui
	$(INSTALL_DATA) ./root/etc/config/openlistui $(1)/etc/config/openlistui
	
	# 安装 UCI 默认脚本
	$(INSTALL_BIN) ./root/etc/uci-defaults/40_luci-openlistui $(1)/etc/uci-defaults/40_luci-openlistui
	
	# 安装 ACL 配置文件
	$(INSTALL_DATA) ./root/usr/share/rpcd/acl.d/luci-app-openlistui.json $(1)/usr/share/rpcd/acl.d/luci-app-openlistui.json
	
	# 编译并安装翻译文件
	if [ -d "./po" ]; then \
		for lang in ./po/*/; do \
			if [ -d "$$lang" ]; then \
				langcode=$$(basename "$$lang"); \
				$(INSTALL_DIR) $(1)/usr/lib/lua/luci/i18n; \
				if [ -f "$$lang/openlistui.po" ]; then \
					if command -v po2lmo >/dev/null 2>&1; then \
						po2lmo "$$lang/openlistui.po" $(1)/usr/lib/lua/luci/i18n/openlistui.$$langcode.lmo; \
					else \
						$(INSTALL_DATA) "$$lang/openlistui.po" $(1)/usr/lib/lua/luci/i18n/openlistui.$$langcode.po; \
					fi; \
				fi; \
			fi; \
		done; \
	fi
endef

# 显示版本信息
.PHONY: version
version:
	@echo "Package: $(PKG_NAME)"
	@echo "Version: $(PKG_VERSION) (base: $(PKG_VERSION_BASE), patch: $(PKG_VERSION_PATCH))"
	@echo "Release: $(PKG_RELEASE)"
	@echo "Build Date: $(PKG_BUILD_DATE)"
	@echo "Build Host: $(PKG_BUILD_HOST)"
	@echo "Build Arch: $(PKG_BUILD_ARCH)"
	@echo "Git Hash: $(PKG_GIT_HASH)"
	@echo "Git Branch: $(PKG_GIT_BRANCH)"

# 生成版本信息文件（用于调试）
.PHONY: gen-version
gen-version:
	@mkdir -p build-info
	@echo "# OpenList UI Version Information" > build-info/version.txt
	@echo "# Generated on $(PKG_BUILD_DATE)" >> build-info/version.txt
	@echo "" >> build-info/version.txt
	@echo "PKG_NAME=$(PKG_NAME)" >> build-info/version.txt
	@echo "PKG_VERSION=$(PKG_VERSION)" >> build-info/version.txt
	@echo "PKG_VERSION_BASE=$(PKG_VERSION_BASE)" >> build-info/version.txt
	@echo "PKG_VERSION_PATCH=$(PKG_VERSION_PATCH)" >> build-info/version.txt
	@echo "PKG_RELEASE=$(PKG_RELEASE)" >> build-info/version.txt
	@echo "BUILD_DATE=$(PKG_BUILD_DATE)" >> build-info/version.txt
	@echo "BUILD_HOST=$(PKG_BUILD_HOST)" >> build-info/version.txt
	@echo "BUILD_ARCH=$(PKG_BUILD_ARCH)" >> build-info/version.txt
	@echo "GIT_HASH=$(PKG_GIT_HASH)" >> build-info/version.txt
	@echo "GIT_BRANCH=$(PKG_GIT_BRANCH)" >> build-info/version.txt
	@echo "Version file generated: build-info/version.txt"

$(eval $(call BuildPackage,luci-app-openlistui))
