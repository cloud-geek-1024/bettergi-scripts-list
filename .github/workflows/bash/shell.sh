config_git_user(){
  local name=${1}
  local email=${2}
  git config --global user.name "$name"
  git config --global user.email "$email"
}

check_force_mode() {
  local event_name="${1}"
  local force_push="${2}"

  if [[ "${event_name}" == "workflow_dispatch" && "${force_push}" == "true" ]]; then
    echo "🔥 强制推送模式已启用（跳过检查）"
    echo "true"  # 正确返回值：用 echo 输出
  else
    echo "✅ 正常同步模式（执行检查）"
    echo "false" # 正确返回值
  fi
}
config_git_global(){
    echo "📦 配置 GitHub 全局用户信息..."
    git config --global user.email "GitHub-Action@action.com"
    git config --global user.name "GitHub Action"
}
config_git_remote(){
  local URL=${1}
  git remote remove origin 2>/dev/null || true
  git remote add origin "$URL"
}
config_github_remote(){
    local GITHUB_USERNAME=${1}
    local GITHUB_TOKEN=${2}
    local GITHUB_REPO_NAME=${3:-"bettergi-scripts-list"}
    local GITHUB_URL="https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com/${GITHUB_USERNAME}/${GITHUB_REPO_NAME}.git"
    echo "📦 配置 GitHub 远程地址...-->${GITEE_URL}"

    config_git_global

#    git remote remove origin 2>/dev/null || true
#    git remote add origin "$GITHUB_URL"
    config_git_remote "$GITHUB_URL"

    echo "✓ GitHub 远程地址已配置"
    echo "REMOTE_GITHUB_URL=${GITHUB_URL}" >> $GITHUB_ENV
}

config_gitee_remote(){
    local GITEE_USERNAME=${1}
    local GITEE_TOKEN=${2}
    local GITEE_REPO_NAME=${3:-"bettergi-scripts-list"}
    local GITEE_URL="https://${GITEE_USERNAME}:${GITEE_TOKEN}@gitee.com/${GITEE_USERNAME}/${GITEE_REPO_NAME}.git"
    echo "📦 配置 Gitee 远程地址...-->${GITEE_URL}"

    config_git_global

#    git remote remove origin 2>/dev/null || true
#    git remote add origin "$GITEE_URL"
    config_git_remote "$GITEE_URL"

    echo "✓ Gitee 远程地址已配置"
    echo "REMOTE_GITEE_URL=${GITEE_URL}" >> $GITHUB_ENV
}

check_github_gitee_diff(){
  local GITEE_USERNAME=${1}
  local GITEE_TOKEN=${2}
  local GITEE_REPO_NAME=${3:-"bettergi-scripts-tools"}
  local SYNC_TASK_BRANCH=${4:-"main"}
  local GITEE_BRANCH=${5:-"master"}

  if git ls-remote --heads origin "$SYNC_TASK_BRANCH" | grep -q "refs/heads/$SYNC_TASK_BRANCH"; then
    echo "✓ 远程分支 $SYNC_TASK_BRANCH 存在"
    git fetch origin "$SYNC_TASK_BRANCH"
    git checkout -B "$SYNC_TASK_BRANCH" origin/"$SYNC_TASK_BRANCH"
  else
    echo "⚠️ 远程分支 $SYNC_TASK_BRANCH 不存在"
  fi

  echo "🔍 检查 GitHub 与 Gitee 的差异..."
#  local GITHUB_URL=$(git remote get-url origin 2>/dev/null || echo "")
  local GITHUB_URL=${REMOTE_GITHUB_URL}
  echo "✓ 已保存 GitHub 远程地址"

  local GITEE_URL="https://${GITEE_USERNAME}:${GITEE_TOKEN}@gitee.com/${GITEE_USERNAME}/${GITEE_REPO_NAME}.git"
#
#  git remote remove origin 2>/dev/null || true
#  git remote add origin "$GITEE_URL"

#  config_gitee_remote "${GITEE_USERNAME}" "${GITEE_TOKEN}" "${GITEE_REPO_NAME}"
#  local GITEE_URL="${REMOTE_GITEE_URL}"

  local LOCAL_SHA=$(git rev-parse HEAD)
  echo "本地最新提交：$LOCAL_SHA"

  if GITEE_SHA=$(git ls-remote "$GITEE_URL" "$GITEE_BRANCH" 2>/dev/null | awk '{print $1}'); then
      if [ -n "$GITEE_SHA" ]; then
          echo "Gitee 最新提交：$GITEE_SHA"
          if [ "$LOCAL_SHA" = "$GITEE_SHA" ]; then
             echo "✅ 无需同步，Gitee 已是最新"
             echo "has_changes=false" >> $GITHUB_OUTPUT
#             echo "false"
             exit 0
          else
            echo "⚠️ 检测到差异，需要同步"
            echo "has_changes=true" >> $GITHUB_OUTPUT
#            echo "true"
             if [ -n "$GITHUB_URL" ]; then
               echo "🔄 恢复 GitHub 远程地址..."
#               git remote remove origin 2>/dev/null || true
#               git remote add origin "$GITHUB_URL"
               config_git_remote "$GITHUB_URL"
               echo "✓ GitHub 远程地址已恢复"
             fi
            return
          fi
      fi
  fi

  echo "⚠️ 无法访问 Gitee 仓库（可能是首次同步或权限问题）"
  echo "将执行完整同步"
  echo "has_changes=true" >> $GITHUB_OUTPUT

  if [ -n "$GITHUB_URL" ]; then
    echo "🔄 恢复 GitHub 远程地址..."
#    git remote remove origin 2>/dev/null || true
#    git remote add origin "$GITHUB_URL"
    config_git_remote "$GITHUB_URL"
    echo "✓ GitHub 远程地址已恢复"
  fi
  #echo "true"
}
push_gitee(){
  local GITEE_USERNAME=${1}
  local GITEE_TOKEN=${2}
  local GITEE_REPO_NAME=${3:-"bettergi-scripts-tools"}
  local SYNC_TASK_BRANCH=${4:-"main"}
  local GITEE_BRANCH=${5:-"master"}
  local force_mode=${6}
  local SOURCE_BRANCH=${7:-$(git branch --show-current)}
#  if git rev-parse --verify "$SYNC_TASK_BRANCH" >/dev/null 2>&1; then
#    git checkout "$SYNC_TASK_BRANCH"
#  else
#    echo "⚠️ 分支 $SYNC_TASK_BRANCH 不存在"
#    return
#  fi

  if git ls-remote --heads origin "$SYNC_TASK_BRANCH" | grep -q "refs/heads/$SYNC_TASK_BRANCH"; then
    echo "✓ 远程分支 $SYNC_TASK_BRANCH 存在"
    git fetch origin "$SYNC_TASK_BRANCH"
    git checkout -B "$SYNC_TASK_BRANCH" origin/"$SYNC_TASK_BRANCH"
  else
    echo "⚠️ 远程分支 $SYNC_TASK_BRANCH 不存在"
  fi

  mode_text=""
  [[ "$force_mode" == "true" ]] && mode_text="[强制推送模式] "
#  echo "GITEE_USERNAME=>$GITEE_USERNAME"
#  echo "GITEE_TOKEN=>$GITEE_TOKEN"

#  config_gitee_remote "${GITEE_USERNAME}" "${GITEE_TOKEN}" "${GITEE_REPO_NAME}"

  echo "📦 ${mode_text}开始推送到 Gitee..."

  local GITEE_URL="https://${GITEE_USERNAME}:${GITEE_TOKEN}@gitee.com/${GITEE_USERNAME}/${GITEE_REPO_NAME}.git"
#  local GITEE_URL="${REMOTE_GITEE_URL}"
#  GITEE_URL="https://gitee.com/${GITEE_USERNAME}/${GITEE_REPO_NAME}.git"
#  git remote remove gitee 2>/dev/null || true
#  git remote add gitee "$GITEE_URL"
#  git remote remove origin 2>/dev/null || true
#  git remote add origin "$GITEE_URL"

#  git remote add origin https://username:token@gitee.com/username/repo.git
#  git push -u origin SOURCE_BRANCH:GITEE_BRANCH

  echo "✓ Gitee remote 配置完成"
  echo ""

  echo "📦 推送分支 (${SOURCE_BRANCH} ->${GITEE_BRANCH})..."
#  if git push -f gitee "${SOURCE_BRANCH}:${GITEE_BRANCH}" 2>&1; then
  git push -v -f "${GITEE_URL}" "${SOURCE_BRANCH}:${GITEE_BRANCH}" 2>&1 | tee /dev/stderr
  if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "✓ 分支推送成功"
  else
    echo "✗ 分支推送失败，请检查 Token 权限和用户名"
    return 1
  fi
  #输出日志
  echo "✓ 分支推送完成"
  echo ""

  echo "🏷️ 推送所有标签..."
  local_tag_count=$(git tag -l | wc -l)
  git push -f gitee --tags
  echo "✓ 标签推送完成（共 $local_tag_count 个）"
}


#push_target_repo(){
#  local source=${1}
#  local target=${2}
#  #url|branch|username|token
#  local source_url_temp=$(echo $source | cut -d '|' -f 1)
#  local source_branch=$(echo $source | cut -d '|' -f 2)
#  local source_username=$(echo $source | cut -d '|' -f 3)
#  local source_token=$(echo $source | cut -d '|' -f 4)
#
#  local target_url_temp=$(echo $target | cut -d '|' -f 1)
#  local target_branch=$(echo $target | cut -d '|' -f 2)
#  local target_username=$(echo $target | cut -d '|' -f 3)
#  local target_token=$(echo $target | cut -d '|' -f 4)
#  #remove http:// 和 https://
#  local source_url=$(echo $source_url_temp | sed 's|https\?://||g')
#  local target_url=$(echo $target_url_temp | sed 's|https\?://||g')
#
#  local SOURCE_URL
#  local TARGET_URL
#  if [ -n "$source_token" ]; then
#    SOURCE_URL="https://${source_username}:${source_token}@${source_url}"
#  else
#    SOURCE_URL="https://${source_url}"
#  fi
#
#  if [ -n "$target_token" ]; then
#    TARGET_URL="https://${target_username}:${target_token}@${target_url}"
#  else
#    TARGET_URL="https://${target_url}"
#  fi
#  local repo_name=$(echo $source_url | sed 's|.*/||' | sed 's|\.git$||')
#
#  if [ ! -d "$repo_name" ]; then
#    git clone "$SOURCE_URL" -b "$source_branch"
#  else
#    echo "目录已存在，更新代码"
#  fi
#
#  cd "$repo_name"
#  REPO_NAME="$repo_name"
#  git fetch --all
#  git reset --hard "origin/$source_branch"
#
#  local current_branch=$(git branch --show-current)
#
#  if [ -n "${target_branch}" ] && [ -n "${source_branch}" ]; then
#      git push -f "$TARGET_URL" "${source_branch}:${target_branch}"
#  elif [ -n "${target_branch}" ]; then
#      git push -f "$TARGET_URL" "${current_branch}:${target_branch}"
#  else
##      git push -f "$TARGET_URL" "${current_branch}:${current_branch}"
#      git push -f "$TARGET_URL"  HEAD
#  fi
#
#  cd ..
#
#  if [ -n "$REPO_NAME" ] && [ -d "$REPO_NAME" ]; then
#    	echo "清理仓库目录: $REPO_NAME"
#    	rm -rf "$REPO_NAME" && echo "移除$REPO_NAME 仓库完成"
#  else
#    	echo "NO REPO_NAME 或目录不存在"
#  fi
#}
#check_repo_diff(){
#    local source=${1}
#    local target=${2}
#    #url|branch|username|token
#    local source_url_temp=$(echo $source | cut -d '|' -f 1)
#    local source_branch=$(echo $source | cut -d '|' -f 2)
#    local source_username=$(echo $source | cut -d '|' -f 3)
#    local source_token=$(echo $source | cut -d '|' -f 4)
#
#    local target_url_temp=$(echo $target | cut -d '|' -f 1)
#    local target_branch=$(echo $target | cut -d '|' -f 2)
#    local target_username=$(echo $target | cut -d '|' -f 3)
#    local target_token=$(echo $target | cut -d '|' -f 4)
#    #remove http:// 和 https://
#    local source_url=$(echo $source_url_temp | sed 's|https\?://||g')
#    local target_url=$(echo $target_url_temp | sed 's|https\?://||g')
#
#    local SOURCE_URL
#    local TARGET_URL
#    if [ -n "$source_token" ]; then
#      SOURCE_URL="https://${source_username}:${source_token}@${source_url}"
#    else
#      SOURCE_URL="https://${source_url}"
#    fi
#
#    if [ -n "$target_token" ]; then
#      TARGET_URL="https://${target_username}:${target_token}@${target_url}"
#    else
#      TARGET_URL="https://${target_url}"
#    fi
#    local repo_name=$(echo $source_url | sed 's|.*/||' | sed 's|\.git$||')
#    if [ "${CLONE}" = "false" ]; then
#           if [ -n "$repo_name" ] && [ -d "$repo_name" ]; then
#             	echo "清理仓库目录: $repo_name"
#             	rm -rf "$repo_name" && echo "移除$repo_name 仓库完成"
#           fi
#          git clone "$SOURCE_URL" -b "$source_branch" #--depth=1
#          CLONE=true
#    fi
#
#    cd "$repo_name"
#    #git fetch --unshallow
#  	REPO_NAME="$repo_name"
#
#    local SOURCE_SHA=$(git rev-parse HEAD)
#    echo "SOURCE最新提交：$SOURCE_SHA"
#    local TARGET_SHA=$(git ls-remote "$TARGET_URL" "$target_branch" | awk '{print $1}')
#    echo "TARGET最新提交：$TARGET_SHA"
#
#    #local HAS_DIFF=false
#    if [ "$SOURCE_SHA" = "$TARGET_SHA" ]; then
#      echo "✅ 无需同步，TARGET已是最新"
#    else
#      echo "⚠️ 检测到差异，需要同步"
#      HAS_DIFF=true
#    fi
#    cd ..
#    #export HAS_DIFF
#}
#
#REPO_NAME=""
#HAS_DIFF=false
#CLONE=false
#
#sync(){
#    local source=${1:-$SOURCE}
#    local target=${2:-$TARGET}
#
#    check_repo_diff "${source}" "${target}"
#
#    if [ "${HAS_DIFF}" = "true" ]; then
#    	echo "sync"
#    	push_target_repo "${source}" "${target}"
#    fi
#
#    if [ -n "$REPO_NAME" ] && [ -d "$REPO_NAME" ]; then
#    	echo "清理仓库目录: $REPO_NAME"
#    	rm -rf "$REPO_NAME" && echo "移除$REPO_NAME 仓库完成"
#    else
#    	echo "NO REPO_NAME 或目录不存在"
#    fi
#
#    echo "END==="
#}
#main_sync(){
#  URL_SOURCE=${1:-$URL_SOURCE}
#  BRANCH_SOURCE=${2:-$BRANCH_SOURCE}
#  USERNAME_SOURCE=${3:-$USERNAME_SOURCE}
#  TOKEN_SOURCE=${4:-$TOKEN_SOURCE}
#
#  URL_TARGET=${5:-$URL_TARGET}
#  BRANCH_TARGET=${6:-$BRANCH_TARGET}
#  USERNAME_TARGET=${7:-$USERNAME_TARGET}
#  TOKEN_TARGET=${8:-$TOKEN_TARGET}
#
#  TARGET="${URL_TARGET}|${BRANCH_TARGET}|${USERNAME_TARGET}|${TOKEN_TARGET}"
#  SOURCE="${URL_SOURCE}|${BRANCH_SOURCE}|${USERNAME_SOURCE}|${TOKEN_SOURCE}"
#  sync "${SOURCE}" "${TARGET}"
#}

# ==================== 通用同步函数（TARGET 兼容版）====================

REPO_NAME=""
HAS_DIFF=false

check_repo_diff() {
    local source=${1}
    local target=${2}

    # 解析参数
    local source_url_temp=$(echo "$source" | cut -d '|' -f 1)
    local source_branch=$(echo "$source" | cut -d '|' -f 2)
    local source_username=$(echo "$source" | cut -d '|' -f 3)
    local source_token=$(echo "$source" | cut -d '|' -f 4)

    local target_url_temp=$(echo "$target" | cut -d '|' -f 1)
    local target_branch=$(echo "$target" | cut -d '|' -f 2)
    local target_username=$(echo "$target" | cut -d '|' -f 3)
    local target_token=$(echo "$target" | cut -d '|' -f 4)

    local source_url=$(echo "$source_url_temp" | sed 's|https\?://||g')
    local target_url=$(echo "$target_url_temp" | sed 's|https\?://||g')

    local SOURCE_URL="https://${source_username}:${source_token}@${source_url}"
    local TARGET_URL="https://${target_username}:${target_token}@${target_url}"

    local repo_name=$(echo "$source_url" | sed 's|.*/||' | sed 's|\.git$||')

    echo "🔍 检查差异: ${repo_name} (${source_branch} → ${target_branch})"

    # 清理旧目录
    if [ -d "$repo_name" ]; then
        echo "🧹 清理旧目录: $repo_name"
        rm -rf "$repo_name"
    fi

    # 完整克隆源仓库（兼容 TARGET 平台）
    echo "📥 克隆源仓库..."
    git clone "$SOURCE_URL" -b "$source_branch" "$repo_name" || {
        echo "❌ 克隆失败"
        return 1
    }

    cd "$repo_name" || { echo "❌ 进入目录失败"; return 1; }

    local SOURCE_SHA=$(git rev-parse HEAD)
    echo "SOURCE 最新提交：$SOURCE_SHA"

    # 获取目标最新提交
    local TARGET_SHA=$(git ls-remote "$TARGET_URL" "$target_branch" 2>/dev/null | awk '{print $1}' || echo "")

    echo "TARGET 最新提交：${TARGET_SHA:-无（首次同步）}"

    if [ "$SOURCE_SHA" = "$TARGET_SHA" ] && [ -n "$TARGET_SHA" ]; then
        echo "✅ 无需同步，TARGET 已是最新"
        HAS_DIFF=false
    else
        echo "⚠️ 检测到差异，需要同步"
        HAS_DIFF=true
    fi

    cd ..   # 必须返回上级目录
}

push_target_repo() {
    local source=${1}
    local target=${2}

    local source_url_temp=$(echo "$source" | cut -d '|' -f 1)
    local source_branch=$(echo "$source" | cut -d '|' -f 2)
    local source_username=$(echo "$source" | cut -d '|' -f 3)
    local source_token=$(echo "$source" | cut -d '|' -f 4)

    local target_url_temp=$(echo "$target" | cut -d '|' -f 1)
    local target_branch=$(echo "$target" | cut -d '|' -f 2)
    local target_username=$(echo "$target" | cut -d '|' -f 3)
    local target_token=$(echo "$target" | cut -d '|' -f 4)

    local source_url=$(echo "$source_url_temp" | sed 's|https\?://||g')
    local target_url=$(echo "$target_url_temp" | sed 's|https\?://||g')

    local SOURCE_URL="https://${source_username}:${source_token}@${source_url}"
    local TARGET_URL="https://${target_username}:${target_token}@${target_url}"

    local repo_name=$(echo "$source_url" | sed 's|.*/||' | sed 's|\.git$||')

    echo "🚀 开始推送: ${repo_name} (${source_branch} → ${target_branch})"

    if [ -d "$repo_name" ]; then
        rm -rf "$repo_name"
    fi

    # 完整克隆，但增加配置优化
    git clone "$SOURCE_URL" -b "$source_branch" "$repo_name"
    cd "$repo_name" || { echo "❌ 进入目录失败"; return 1; }

    # 关键优化：提高 Git HTTP 缓冲区 + 低速超时保护
    git config http.postBuffer 524288000          # 500MB 缓冲
    git config http.lowSpeedLimit 1000            # 低于 1KB/s 视为低速
    git config http.lowSpeedTime 60               # 低速持续 60 秒则超时

    echo "📤 执行推送（带优化配置）..."
    # 使用 timeout 命令包裹 push，防止无限卡住（推荐加 30-60 分钟限制）
    if timeout 1800 git push -f "$TARGET_URL" "HEAD:${target_branch}" 2>&1 | tee /dev/stderr; then
        echo "✅ 推送成功"
    else
        echo "❌ 推送失败或超时"
        echo "   可能原因：网络不稳定、Token 权限不足、目标分支保护、仓库过大"
        cd ..
        return 1
    fi

    cd ..
    rm -rf "$repo_name"
    echo "🧹 清理完成"
}

#push_target_repo() {
#    local source=${1}
#    local target=${2}
#
#    local source_url_temp=$(echo "$source" | cut -d '|' -f 1)
#    local source_branch=$(echo "$source" | cut -d '|' -f 2)
#    local source_username=$(echo "$source" | cut -d '|' -f 3)
#    local source_token=$(echo "$source" | cut -d '|' -f 4)
#
#    local target_url_temp=$(echo "$target" | cut -d '|' -f 1)
#    local target_branch=$(echo "$target" | cut -d '|' -f 2)
#    local target_username=$(echo "$target" | cut -d '|' -f 3)
#    local target_token=$(echo "$target" | cut -d '|' -f 4)
#
#    local source_url=$(echo "$source_url_temp" | sed 's|https\?://||g')
#    local target_url=$(echo "$target_url_temp" | sed 's|https\?://||g')
#
#    local SOURCE_URL="https://${source_username}:${source_token}@${source_url}"
#    local TARGET_URL="https://${target_username}:${target_token}@${target_url}"
#
#    local repo_name=$(echo "$source_url" | sed 's|.*/||' | sed 's|\.git$||')
#
#    echo "🚀 开始推送: ${repo_name} (${source_branch} → ${target_branch})"
#
#    # 清理旧目录
#    if [ -d "$repo_name" ]; then
#        rm -rf "$repo_name"
#    fi
#
#    # 完整克隆
#    git clone "$SOURCE_URL" -b "$source_branch" "$repo_name"
#    cd "$repo_name" || { echo "❌ 进入目录失败"; return 1; }
#
#    echo "📤 执行推送..."
#    if git push -f "$TARGET_URL" "HEAD:${target_branch}" 2>&1 | tee /dev/stderr; then
#        echo "✅ 推送成功"
#    else
#        echo "❌ 推送失败"
#        echo "   请检查 Token 权限、目标仓库状态或分支保护设置"
#        cd ..
#        return 1
#    fi
#
#    cd ..
#    rm -rf "$repo_name"
#    echo "🧹 清理完成"
#}

sync() {
    local source=${1}
    local target=${2}

    check_repo_diff "${source}" "${target}"

    if [ "${HAS_DIFF}" = "true" ]; then
        push_target_repo "${source}" "${target}"
    else
        echo "✅ 无差异，跳过推送"
    fi

    echo "=== 同步流程结束 ==="
}

# 保留原来的 main_sync 函数（无需修改）
main_sync(){
  URL_SOURCE=${1:-$URL_SOURCE}
  BRANCH_SOURCE=${2:-$BRANCH_SOURCE}
  USERNAME_SOURCE=${3:-$USERNAME_SOURCE}
  TOKEN_SOURCE=${4:-$TOKEN_SOURCE}

  URL_TARGET=${5:-$URL_TARGET}
  BRANCH_TARGET=${6:-$BRANCH_TARGET}
  USERNAME_TARGET=${7:-$USERNAME_TARGET}
  TOKEN_TARGET=${8:-$TOKEN_TARGET}

  TARGET="${URL_TARGET}|${BRANCH_TARGET}|${USERNAME_TARGET}|${TOKEN_TARGET}"
  SOURCE="${URL_SOURCE}|${BRANCH_SOURCE}|${USERNAME_SOURCE}|${TOKEN_SOURCE}"
  sync "${SOURCE}" "${TARGET}"
}