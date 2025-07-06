import { BaseNavigation } from 'JhCommon';
import { router } from '@kit.ArkUI';
import dataPreferences from '@ohos.data.preferences';
import { common } from '@kit.AbilityKit';

interface ImproveItem {
  title: string;
  desc: string;
  image: string;
  category: string;
  favorite: boolean;
}

interface CategoryOption {
  value: string;
}

@Entry
@Component
export struct SleepImprovePage {
  @State improveList: ImproveItem[] = [];
  @State newTitle: string = '';
  @State newDesc: string = '';
  @State newImage: string = '';
  @State newCategory: string = '';
  @State editingIndex: number = -1;
  @State categoryOptions: CategoryOption[] = [];

  // 持久化相关
  private readonly STORE_NAME = 'SleepImproveStore';
  private preferences: dataPreferences.Preferences | null = null;
  private readonly IMPROVE_LIST_KEY = 'SleepImproveList';

  async aboutToAppear() {
    console.info('[SleepImprovePage] 页面初始化开始');
    await this.initPreferences();
    await this.loadImproveList();
    this.initData();
  }

  // 初始化首选项存储
  private async initPreferences(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      this.preferences = await dataPreferences.getPreferences(context, this.STORE_NAME);
      console.info('[SleepImprovePage] 首选项存储初始化成功');
    } catch (error) {
      console.error(`[SleepImprovePage] 首选项存储初始化失败: ${error}`);
    }
  }

  // 加载改善建议列表
  private async loadImproveList(): Promise<void> {
    try {
      if (this.preferences) {
        const savedListStr = await this.preferences.get(this.IMPROVE_LIST_KEY, '[]') as string;
        const savedList = JSON.parse(savedListStr) as ImproveItem[];
        if (Array.isArray(savedList) && savedList.length > 0) {
          this.improveList = savedList;
          console.info(`[SleepImprovePage] 加载保存的改善建议列表，共${savedList.length}条`);
        }
      }
    } catch (error) {
      console.error(`[SleepImprovePage] 加载改善建议列表失败: ${error}`);
      this.improveList = [];
    }
  }

  // 保存改善建议列表
  private async saveImproveList(): Promise<void> {
    try {
      if (this.preferences) {
        await this.preferences.put(this.IMPROVE_LIST_KEY, JSON.stringify(this.improveList));
        await this.preferences.flush();
        console.info('[SleepImprovePage] 改善建议列表保存成功');
      }
    } catch (error) {
      console.error(`[SleepImprovePage] 保存改善建议列表失败: ${error}`);
    }
  }

  initData() {
    console.info('[SleepImprovePage] 初始化数据');

    this.newCategory = '作息';

    this.categoryOptions = [
      { value: '作息' },
      { value: '放松' },
      { value: '环境' },
      { value: '饮食' },
      { value: '运动' }
    ];

    // 如果没有保存的数据，使用默认数据
    if (this.improveList.length === 0) {
      this.improveList = [
        {
          title: '规律作息',
          desc: '每天同一时间上床和起床，帮助生物钟稳定',
          image: 'images/schedule.png',
          category: '作息',
          favorite: false
        },
        {
          title: '睡前放松',
          desc: '睡前可听舒缓音乐、冥想或泡脚，帮助身心放松',
          image: 'images/relax.png',
          category: '放松',
          favorite: false
        },
        {
          title: '减少电子产品',
          desc: '睡前1小时减少手机、电脑等蓝光刺激',
          image: 'images/no_phone.png',
          category: '环境',
          favorite: false
        }
      ];
      // 保存默认数据
      this.saveImproveList();
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
            console.info('[SleepImprovePage] 返回上一页');
            router.back();
          } catch (err) {
            console.error('[SleepImprovePage] 返回失败:', err);
            router.pushUrl({ url: 'pages/three/pages/WxDiscoverPage' });
          }
        })
        .width(40)
        .height(40)
        .backgroundColor(Color.Transparent)
        .margin({ left: 10 })

        Blank().layoutWeight(1)

        Text('睡眠改善')
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

      // 改善建议列表
      Scroll() {
        Column() {
          ForEach(this.improveList, (item: ImproveItem, index: number) => {
            ListItem() {
              Row() {
                Image($rawfile(item.image))
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
                  .onClick(() => { this.deleteImprove(index); })
                  .width(32)
                  .height(32)
                  .backgroundColor('#FFE5E5')
                  .margin({ bottom: 8 })
                  Button({ type: ButtonType.Circle }) {
                    Image($r('app.media.ic_back'))
                      .width(18)
                      .height(18)
                  }
                  .onClick(() => { this.editImprove(index); })
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
        Text(this.editingIndex >= 0 ? '编辑睡眠建议' : '添加睡眠改善建议')
          .fontSize(16)
          .margin({ bottom: 8 })
        TextInput({
          placeholder: '建议标题',
          text: this.newTitle
        })
          .onChange((value: string) => { this.newTitle = value; })
          .margin({ bottom: 8 })
        TextInput({
          placeholder: '建议描述',
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
              console.info(`[SleepImprovePage] 选择分类: ${value}`);
            })
            .width(120)
            .height(36)
            .backgroundColor('#F5F5F5')
            .borderRadius(8)
        }
        .margin({ bottom: 8 })
        Button(this.editingIndex >= 0 ? '保存修改' : '添加建议')
          .onClick(() => { this.saveImprove(); })
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

  deleteImprove(index: number) {
    console.info(`[SleepImprovePage] 删除改善建议，索引: ${index}`);
    this.improveList.splice(index, 1);
    if (this.editingIndex === index) {
      this.editingIndex = -1;
      this.newTitle = '';
      this.newDesc = '';
      this.newImage = '';
      this.newCategory = '作息';
    }
    // 保存到持久化存储
    this.saveImproveList();
  }

  editImprove(index: number) {
    console.info(`[SleepImprovePage] 编辑改善建议，索引: ${index}`);
    this.editingIndex = index;
    this.newTitle = this.improveList[index].title;
    this.newDesc = this.improveList[index].desc;
    this.newImage = this.improveList[index].image;
    this.newCategory = this.improveList[index].category;
  }

  saveImprove() {
    if (!this.newTitle || !this.newDesc) {
      console.warn('[SleepImprovePage] 标题或描述为空，无法保存');
      return;
    }

    if (this.editingIndex >= 0) {
      console.info(`[SleepImprovePage] 更新改善建议: ${this.newTitle}`);
      this.improveList[this.editingIndex].title = this.newTitle;
      this.improveList[this.editingIndex].desc = this.newDesc;
      this.improveList[this.editingIndex].image = this.newImage || 'images/sleep_default.png';
      this.improveList[this.editingIndex].category = this.newCategory;
      this.editingIndex = -1;
    } else {
      console.info(`[SleepImprovePage] 添加新的改善建议: ${this.newTitle}`);
      this.improveList.push({
        title: this.newTitle,
        desc: this.newDesc,
        image: this.newImage || 'images/sleep_default.png',
        category: this.newCategory,
        favorite: false
      });
    }

    // 重置表单
    this.newTitle = '';
    this.newDesc = '';
    this.newImage = '';
    this.newCategory = '作息';

    // 保存到持久化存储
    this.saveImproveList();
  }
}