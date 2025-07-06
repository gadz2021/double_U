///  WxMinePage.ets
///
///  Created by iotjin on 2024/11/06.
//"我的"页面
//是第四页主页

import { BaseNavigation, JhSetCell, KColors, JhProgressHUD } from 'JhCommon'
import { router } from '@kit.ArkUI';
import { UserApiService, userApiService, UserProfileResponse } from '../../../services/api_network/UserApiService';

const _cellH = 55.0;
const _leftSpace = 50.0;
const _rowSpace = 6.0;

interface AvatarInfo {
  serverUrl: string;
  uploadStatus: 'uploading' | 'success' | 'failed' | 'none';
}

interface UserInfoFromStorage {
  userId: string;
  userName: string;
  phone: string;
  loginTime: string;
}

@Entry
@Preview
@Component
export struct WxMinePage {
  scroller: Scroller = new Scroller()
  @State topH: number = 0
  @State userName: string = '';
  @State avatarInfo: AvatarInfo = {
    serverUrl: '',
    uploadStatus: 'none'
  }
  @State currentUserId: number = 1
  @State isRefreshing: boolean = false

  // 从服务器加载用户资料
  private async loadUserProfile(): Promise<void> {
    try {
      console.info(`[我的页面] 开始从服务器加载用户${this.currentUserId}的资料`);

      const profileResult: UserProfileResponse = await userApiService.getUserProfile(this.currentUserId);

      if (profileResult.success && profileResult.data) {
        // 更新用户名
        this.userName = profileResult.data.username;

        // 更新头像
        if (profileResult.data.avatar_url) {
          this.avatarInfo.serverUrl = profileResult.data.avatar_url;
        }
        console.info(`[我的页面] 服务器资料加载成功，用户名: ${profileResult.data.username}，头像: ${profileResult.data.avatar_url || '无'}`);
      } else {
        console.error(`[我的页面] 服务器资料加载失败: ${profileResult.message}`);
      }
    } catch (error) {
      console.error(`[我的页面] 服务器资料加载异常: ${error}`);
    }
  }

  // 下拉刷新处理函数
  async onRefresh(): Promise<void> {
    console.info('[我的页面] 用户触发下拉刷新');
    this.isRefreshing = true;

    try {
      await this.getUserId();
      await this.loadUserProfile();
      console.info('[我的页面] 下拉刷新完成');
    } catch (error) {
      console.error('[我的页面] 下拉刷新失败:', error);
      JhProgressHUD.showToast('刷新失败，请重试');
    } finally {
      this.isRefreshing = false;
    }
  }

  // 获取显示的头像源
  private getAvatarSource(): string | Resource {
    if (this.avatarInfo.serverUrl) {
      return UserApiService.getAvatarUrl(this.avatarInfo.serverUrl);
    }
    return 'https://gitee.com/zhaozehe/zako/raw/master/ic_535a5f26fa59f35f023467562ae1388e.png';
  }

  // 获取用户ID
  private async getUserId(): Promise<void> {
    try {
      console.info('[我的页面] === 开始获取用户ID ===');
      const userInfoStr = AppStorage.get<string>('userInfo');

      if (userInfoStr) {
        const userInfo: UserInfoFromStorage = JSON.parse(userInfoStr) as UserInfoFromStorage;
        if (userInfo && userInfo.userId) {
          this.currentUserId = parseInt(userInfo.userId);
          console.info(`[我的页面] === 获取到用户ID: ${this.currentUserId} ===`);
        } else {
          console.warn('[我的页面] === 未找到用户信息，使用默认ID ===');
          this.currentUserId = 1;
        }
      } else {
        console.warn('[我的页面] === AppStorage中无用户信息，使用默认ID ===');
        this.currentUserId = 1;
      }
    } catch (error) {
      console.error(`[我的页面] === 获取用户ID异常: ${error} ===`);
      this.currentUserId = 1;
    }
  }

  aboutToAppear() {
    console.info('[我的页面] 页面初始化开始');
    this.getUserId().then(() => {
      this.loadUserProfile();
    });
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Row()
        .width('100%')
        .height(this.topH + 50)
        .backgroundColor(Color.White)
      this.body()
      BaseNavigation({
        title: '',
        bgColor: Color.Transparent,
        leftItem: {},
        rightImgPath: $rawfile("images/ic_set_black.png"),
        rightItemCallBack: () => {
          this.clickCell('设置')
        },
      })
        .hitTestBehavior(HitTestMode.Transparent)
    }
    .backgroundColor(KColors.wxBgColor)
  }

  @Builder
  body() {
    Refresh({ refreshing: $$this.isRefreshing }) {
      List({ scroller: this.scroller }) {
        this.header()
        ListItem() {
          Column() {
            Blank().height(_rowSpace)
            JhSetCell({
              cellHeight: _cellH,
              leftIcon: $rawfile("wechat/mine/ic_wallet.png"),
              title: '会员中心',
              hiddenLine: true,
              clickCallBack: (): void => this.clickCell('会员中心'),
            })
            Blank().height(_rowSpace)
            JhSetCell({
              cellHeight: _cellH,
              lineLeftEdge: _leftSpace,
              leftIcon: $rawfile("wechat/mine/ic_collections.png"),
              title: '健康档案',
              clickCallBack: (): void => {
                this.clickCell('健康档案')
              },
            })
            JhSetCell({
              cellHeight: _cellH,
              lineLeftEdge: _leftSpace,
              leftIcon: $rawfile("wechat/mine/ic_album.png"),
              title: '精力助手',
              clickCallBack: (): void => {
                this.clickCell('精力助手')
              },
            })
            JhSetCell({
              cellHeight: _cellH,
              lineLeftEdge: _leftSpace,
              leftIcon: $rawfile("wechat/mine/ic_cards_wallet.png"),
              title: '知识专题',
              hiddenLine: true,
              clickCallBack: (): void => this.clickCell('知识专题'),
            })
            Blank().height(_rowSpace)
            JhSetCell({
              cellHeight: _cellH,
              lineLeftEdge: _leftSpace,
              leftIcon: $rawfile("wechat/mine/ic_emotions.png"),
              title: '健康积分',
              hiddenLine: true,
              clickCallBack: (): void => this.clickCell('健康积分'),
            })
            Blank().height(_rowSpace)
            JhSetCell({
              cellHeight: _cellH,
              leftIcon: $rawfile("wechat/mine/ic_settings.png"),
              title: '设置',
              hiddenLine: true,
              clickCallBack: (): void => this.clickCell('设置'),
            })
            Blank().height(_rowSpace)
            JhSetCell({
              cellHeight: _cellH,
              leftIcon: $rawfile("images/ic_about.png"),
              title: '检查更新',
              text: '有新版本',
              textStyle: { fontSize: 14, fontColor: Color.Red },
              hiddenLine: true,
              clickCallBack: (): void => this.clickCell('检查更新'),
            })
            Blank().height(50)
          }
        }
      }
      .height('100%')
      .edgeEffect(EdgeEffect.Spring, {
        alwaysEnabled: true
      })
      .backgroundColor(Color.Transparent)
      .onDidScroll(() => {
        this.handleScroll()
      })
    }
    .onRefreshing(() => {
      this.onRefresh()
    })
  }

  handleScroll() {
    const y = this.scroller.currentOffset().yOffset
    if (y < 0 && y > -1000) {
      this.topH = Math.abs(y)
    }
  }

  @Builder
  header() {
    Row() {
      Image(this.getAvatarSource()).width(75).height(75).borderRadius(10)
        .onError(() => {
          console.error('[我的页面] 头像加载失败')
        })
        .onClick(() => {
          this.clickCell('个人信息')
        })
      Column() {
        Text(this.userName || '加载中...')
          .fontSize(28)
          .fontWeight(FontWeight.Medium)
          .textAlign(TextAlign.Start)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .onClick(() => {
            this.clickCell('个人信息')
          })
        Row() {
          Text() {
            Span('健康ID: ')
            Span('abc')
          }
          .fontSize(17)
          .fontColor(Color.Gray)
          Blank()
          Image($rawfile('wechat/mine/ic_setting_myQR.png')).width(18).height(18).margin({ right: 20 })
          Image($rawfile('JhForm/ic_arrow_right.svg')).width(25).height(25)
        }
        .margin({ top: 10 })
        .width('100%')
        .onClick(() => {
          this.clickCell('个人信息')
        })
      }
      .layoutWeight(1)
      .padding({ left: 16 })
    }
    .backgroundColor(Color.White)
    .padding({
      left: 15,
      right: 15,
      top: 40,
      bottom: 30
    })
  }

  onPageShow() {
    console.info('[我的页面] 页面显示，重新加载用户资料');
    this.loadUserProfile();
  }

  clickCell(title: string) {
    console.info(`[我的页面] 点击功能: ${title}`);

    if (title === '会员中心') {
      router.pushUrl({ url: 'pages/four/pages/Membership/MemberShip' })
    } else if (title === '个人信息') {
      router.pushUrl({ url: 'pages/four/pages/WxPersonInfoPage' })
    } else if (title === '设置') {
      router.pushUrl({ url: 'pages/four/pages/setpage/SetPage' })
    } else if (title === '健康积分') {
      router.pushUrl({ url: 'pages/four/pages/jifen/JifenPage' })
    } else if (title === '知识专题') {
      router.pushUrl({ url: 'pages/four/pages/knowledge/knowledge' })
    } else if (title === '健康档案') {
      router.pushUrl({ url: 'pages/four/pages/health/HealthRecordsPage' })
    } else if (title === '精力助手') {
      router.pushUrl({ url: 'pages/four/pages/energy_assistant/EnergyAssistantPage' })
    } else if (title === '检查更新') {
      router.pushUrl({url: 'pages/four/pages/gengxin/JianChaGengXinPage'})
    }
  }
}