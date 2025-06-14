///  JhTextList.ets
///
///  Created by iotjin on 2024/08/05.
///  description: 带箭头文本列表

import { KColors } from '../configs/Colors';
import { BaseNavigation } from './BaseNavigation';

export interface ItemType {
  label: string | Resource
  value?: string
  text?: Resource
}

const _lfSpace = 10.0
const _cellHeight = 50.0
const _lineHeight = 1.0
const _lineColor = KColors.kLineColor
const _lineDarkColor = KColors.kLineDarkColor
const _cellBgColor = KColors.kCellBgColor
const _cellBgDarkColor = KColors.kCellBgDarkColor

@Preview
@Component
export struct JhTextList {
  @Prop public title: string | Resource = ''
  @Prop public dataArr: ESObject[] = []
  public callBack?: (selectIndex: number, selectStr: string) => void

  build() {
    Scroll() {
      Column() {
        BaseNavigation({ title: this.title ,bgColor: Color.Transparent })
        List() {
          ForEach(this.dataArr, (item: ItemType, index: number) => {
            this.itemBuild(item, index)
          })
        }
        .width('100%')
        .height('100%')
        .layoutWeight(1)

        // // divider 第一个子组件上方和最后一个子组件下方不会绘制分割线
        // .divider({
        //   strokeWidth: _lineHeight, // 设置分割线宽度
        //   color: _lineColor // 设置分割线颜色
        // })
      }
      .layoutWeight(1)
    }
  }

  @Builder
  itemBuild(item: ItemType, index: number) {
    Column() {
      Row() {
        Row() {
          Text(item.label)
            .fontSize(18)
          if (item.text) {
            Text(item.text)
              .fontSize(18)
          }
        }
        .layoutWeight(1)
        .margin({ top: 10, bottom: 10 })

        Image($rawfile("common/ic_arrow_black.png"))
          .size({ width: 18, height: 18 })
          .margin({ left: 10 })
      }
      .width('100%')
      // .height(_cellHeight - _lineHeight)
      .constraintSize({
        minHeight: _cellHeight - _lineHeight,
      })
      .justifyContent(FlexAlign.SpaceBetween)

      Row() {
      }
      .size({ width: '100%', height: _lineHeight })
      .backgroundColor(_lineColor)
    }
    .padding({ left: _lfSpace, right: _lfSpace })
    .backgroundColor(_cellBgColor)
    .onClick(() => {
      if (this.callBack) {
        const labelValue = typeof item.label === 'string' ? item.label : index.toString()
        this.callBack(index, labelValue)
      }
    })
  }
}