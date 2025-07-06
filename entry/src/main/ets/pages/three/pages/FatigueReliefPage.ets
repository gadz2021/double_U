import { BaseNavigation } from 'JhCommon';
import { router } from '@kit.ArkUI';
import dataPreferences from '@ohos.data.preferences';
import { common } from '@kit.AbilityKit';

///疲劳缓解页面

interface ReliefItem {
  title: string;
  desc: string;
  cover: string;
  category: string;
  favorite: boolean;
}

interface CategoryOption {
  value: string;
}

@Entry
@Component
export struct FatigueReliefPage {
  @State reliefList: ReliefItem[] = [];
  @State newTitle: string = '';
  @State newDesc: string = '';
  @State newCover: string = '';
  @State newCategory: string = '';
  @State editingIndex: number = -1;
  @State categoryOptions: CategoryOption[] = [];

  // 持久化相关
  private readonly STORE_NAME = 'FatigueReliefStore';
  private preferences: dataPreferences.Preferences | null = null;
  private readonly RELIEF_LIST_KEY = 'FatigueReliefList';

  async aboutToAppear() {
    console.info('[FatigueReliefPage] 页面初始化开始');
    await this.initPreferences();
    await this.loadReliefList();
    this.initData();
  }

  // 初始化首选项存储
  private async initPreferences(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      this.preferences = await dataPreferences.getPreferences(context, this.STORE_NAME);
      console.info('[FatigueReliefPage] 首选项存储初始化成功');
    } catch (error) {
      console.error(`[FatigueReliefPage] 首选项存储初始化失败: ${error}`);
    }
  }

  // 加载疲劳缓解列表
  private async loadReliefList(): Promise<void> {
    try {
      if (this.preferences) {
        const savedListStr = await this.preferences.get(this.RELIEF_LIST_KEY, '[]') as string;
        const savedList = JSON.parse(savedListStr) as ReliefItem[];
        if (Array.isArray(savedList) && savedList.length > 0) {
          this.reliefList = savedList;
          console.info(`[FatigueReliefPage] 加载保存的疲劳缓解列表，共${savedList.length}条`);
        }
      }
    } catch (error) {
      console.error(`[FatigueReliefPage] 加载疲劳缓解列表失败: ${error}`);
      this.reliefList = [];
    }
  }

  // 保存疲劳缓解列表
  private async saveReliefList(): Promise<void> {
    try {
      if (this.preferences) {
        await this.preferences.put(this.RELIEF_LIST_KEY, JSON.stringify(this.reliefList));
        await this.preferences.flush();
        console.info('[FatigueReliefPage] 疲劳缓解列表保存成功');
      }
    } catch (error) {
      console.error(`[FatigueReliefPage] 保存疲劳缓解列表失败: ${error}`);
    }
  }

  initData() {
    console.info('[FatigueReliefPage] 初始化数据');

    this.newCategory = '全身';

    this.categoryOptions = [
      { value: '全身' },
      { value: '眼部' },
      { value: '颈部' },
      { value: '手部' },
      { value: '腿部' }
    ];

    // 如果没有保存的数据，使用默认数据
    if (this.reliefList.length === 0) {
      this.reliefList = [
        {
          title: '眼部运动',
          desc: '缓解眼部疲劳，适合长时间用眼后使用',
          cover: 'images/eye_exercise.png',
          category: '眼部',
          favorite: false
        },
        {
          title: '颈部拉伸',
          desc: '缓解颈部僵硬，改善血液循环',
          cover: 'images/neck_stretch.png',
          category: '颈部',
          favorite: false
        },
        {
          title: '深呼吸',
          desc: '通过深呼吸放松全身，缓解整体疲劳',
          cover: 'images/breath.png',
          category: '全身',
          favorite: false
        }
      ];
      // 保存默认数据
      this.saveReliefList();
    }
  }

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Button({ type: ButtonType.Circle }) {
          Image($r('app.media.ic_back'))
            .width(20)
            .height(20)
        }
        .onClick(() => {
          try {
            console.info('[FatigueReliefPage] 返回上一页');
            router.back();
          } catch (err) {
            console.error('[FatigueReliefPage] 返回失败:', err);
            router.pushUrl({ url: 'pages/three/pages/WxDiscoverPage' });
          }
        })
        .width(40)
        .height(40)
        .backgroundColor(Color.Transparent)
        .margin({ left: 10 })

        Blank().layoutWeight(1)

        Text('疲劳缓解')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.Black)
          .margin({ top: 20, bottom: 20 })

        Blank().layoutWeight(1)
        Blank().width(40).height(40).margin({ right: 10 })
      }
      .width('100%')
      .height(60)
      .justifyContent(FlexAlign.Center)
      .backgroundColor('#F8F8F8')

      // 疲劳缓解方法列表
      Scroll() {
        Column() {
          ForEach(this.reliefList, (item: ReliefItem, index: number) => {
            ListItem() {
              Row() {
                Image($rawfile(item.cover))
                  .width(60)
                  .height(60)
                  .borderRadius(8)
                  .margin({ right: 10 })
                Column() {
                  Row() {
                    Text(item.title)
                      .fontSize(18)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#222222')
                    Text(` [${item.category}]`)
                      .fontSize(13)
                      .fontColor('#888888')
                      .margin({ left: 6 })
                  }
                  Text(item.desc)
                    .fontSize(14)
                    .fontColor('#666666')
                    .margin({ top: 5 })
                }
                .layoutWeight(1)
                Column() {
                  Button({ type: ButtonType.Circle }) {
                    Image($r('app.media.ic_delete'))
                      .width(18)
                      .height(18)
                  }
                  .onClick(() => { this.deleteRelief(index); })
                  .width(32)
                  .height(32)
                  .backgroundColor('#FFE5E5')
                  .margin({ bottom: 8 })
                  Button({ type: ButtonType.Circle }) {
                    Image($r('app.media.ic_back'))
                      .width(18)
                      .height(18)
                  }
                  .onClick(() => { this.editRelief(index); })
                  .width(32)
                  .height(32)
                  .backgroundColor('#E5F0FF')
                }
              }
              .width('100%')
              .padding(14)
              .backgroundColor(Color.White)
              .borderRadius(14)
              .margin({ bottom: 12 })
              .shadow({ radius: 4, color: '#1A000000', offsetY: 2 })
            }
          })
        }
        .padding(16)
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor('#F0F0F0')

      // 添加/编辑区域
      Column() {
        Text(this.editingIndex >= 0 ? '编辑疲劳缓解方法' : '添加疲劳缓解方法')
          .fontSize(16)
          .margin({ bottom: 8 })
        TextInput({
          placeholder: '方法标题',
          text: this.newTitle
        })
          .onChange((value: string) => { this.newTitle = value; })
          .margin({ bottom: 8 })
        TextInput({
          placeholder: '方法描述',
          text: this.newDesc
        })
          .onChange((value: string) => { this.newDesc = value; })
          .margin({ bottom: 8 })
        Row() {
          Select(this.categoryOptions)
            .selected(this.categoryOptions.findIndex((option: CategoryOption) => option.value === this.newCategory))
            .value(this.newCategory)
            .onSelect((index: number, value: string) => {
              this.newCategory = value;
              console.info(`[FatigueReliefPage] 选择分类: ${value}`);
            })
            .width(120)
            .height(36)
            .backgroundColor('#F5F5F5')
            .borderRadius(8)
        }
        .margin({ bottom: 8 })
        Button(this.editingIndex >= 0 ? '保存修改' : '添加方法')
          .onClick(() => { this.saveRelief(); })
          .width('100%')
          .height(44)
          .backgroundColor('#4285F4')
          .fontColor(Color.White)
          .borderRadius(22)
          .margin({ top: 8 })
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#f0f0f0')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F0F0F0')
  }

  deleteRelief(index: number) {
    console.info(`[FatigueReliefPage] 删除疲劳缓解方法，索引: ${index}`);
    this.reliefList.splice(index, 1);
    if (this.editingIndex === index) {
      this.editingIndex = -1;
      this.newTitle = '';
      this.newDesc = '';
      this.newCover = '';
      this.newCategory = '全身';
    }
    // 保存到持久化存储
    this.saveReliefList();
  }

  editRelief(index: number) {
    console.info(`[FatigueReliefPage] 编辑疲劳缓解方法，索引: ${index}`);
    this.editingIndex = index;
    this.newTitle = this.reliefList[index].title;
    this.newDesc = this.reliefList[index].desc;
    this.newCover = this.reliefList[index].cover;
    this.newCategory = this.reliefList[index].category;
  }

  saveRelief() {
    if (!this.newTitle || !this.newDesc) {
      console.warn('[FatigueReliefPage] 标题或描述为空，无法保存');
      return;
    }

    if (this.editingIndex >= 0) {
      console.info(`[FatigueReliefPage] 更新疲劳缓解方法: ${this.newTitle}`);
      this.reliefList[this.editingIndex].title = this.newTitle;
      this.reliefList[this.editingIndex].desc = this.newDesc;
      this.reliefList[this.editingIndex].cover = this.newCover || 'images/relief_default.png';
      this.reliefList[this.editingIndex].category = this.newCategory;
      this.editingIndex = -1;
    } else {
      console.info(`[FatigueReliefPage] 添加新的疲劳缓解方法: ${this.newTitle}`);
      this.reliefList.push({
        title: this.newTitle,
        desc: this.newDesc,
        cover: this.newCover || 'images/relief_default.png',
        category: this.newCategory,
        favorite: false
      });
    }

    // 重置表单
    this.newTitle = '';
    this.newDesc = '';
    this.newCover = '';
    this.newCategory = '全身';

    // 保存到持久化存储
    this.saveReliefList();
  }
}