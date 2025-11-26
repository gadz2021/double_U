import http from '@ohos.net.http';
import { BusinessError } from '@ohos.base';
import util from '@ohos.util';

// 首先定义所需的接口和类
interface ConversationItem {
  role: string;
  content: string;
}

class ChatMessage {
  role: string;
  content: string;

  constructor(role: string, content: string) {
    this.role = role;
    this.content = content;
  }
}

// 为对象字面量创建明确的类型
class RequestHeader {
  'Content-Type': string = 'application/json';
  'Authorization': string = '';

  constructor(apiKey: string) {
    this.Authorization = `Bearer ${apiKey}`;
  }
}

class RequestBody {
  model: string;
  messages: ChatMessage[];
  temperature: number;
  stream: boolean;

  constructor(model: string, messages: ChatMessage[]) {
    this.model = model;
    this.messages = messages;
    this.temperature = 0.7;
    this.stream = true;
  }
}

class DeltaContent {
  content?: string;

  constructor(content?: string) {
    this.content = content;
  }
}

class ChoiceItem {
  delta: DeltaContent;

  constructor() {
    this.delta = new DeltaContent();
  }
}

class StreamChunk {
  choices: Array<ChoiceItem> = [];

  constructor() {
    this.choices = [];
  }
}

export class DeepSeekService {
  private static readonly BASE_URL: string = 'https://api.siliconflow.cn/v1/';
  private static readonly API_KEY: string = 'sk-kvgnywlwydfxodlynigenzpmlaetthwsjncqnyobrcxaykdt';
  // 再偷偷用我api_key给你玛莎拉

  /**
   * 发送真正的流式请求到DeepSeek API
   */
  static streamRequest(
    userMessage: string,
    conversation?: ConversationItem[],
    onUpdate?: (chunk: string) => void,
    onComplete?: () => void,
    onError?: (error: Error) => void,
    model: string = 'deepseek-ai/DeepSeek-V3'
  ): () => void {
    console.info(`[流式请求] 开始请求，用户消息: ${userMessage.substring(0, 30)}...`);
    console.info(`[流式请求] 对话历史长度: ${conversation?.length || 0}`);

    // 创建HTTP请求对象
    const httpRequest = http.createHttp();
    let fullResponse: string = '';

    try {
      // 构建消息数组
      const messages: ChatMessage[] = [];
      if (conversation && conversation.length > 0) {
        conversation.forEach(item => {
          messages.push(new ChatMessage(item.role, item.content));
        });

        if (messages[messages.length - 1].role !== 'user') {
          messages.push(new ChatMessage('user', userMessage));
        }
      } else {
        messages.push(new ChatMessage('user', userMessage));
      }

      // 创建请求体，启用流式输出
      const requestBody: RequestBody = new RequestBody(model, messages);

      console.info(`[流式请求] 请求参数: ${JSON.stringify({
        model: requestBody.model,
        stream: requestBody.stream,
        messagesCount: requestBody.messages.length
      })}`);

      // 设置请求头
      const header: RequestHeader = new RequestHeader(DeepSeekService.API_KEY);

      // 1. 监听头部接收事件
      httpRequest.on('headersReceive', (headers: Object) => {
        console.info(`[流式响应] 收到响应头: ${JSON.stringify(headers)}`);
      });

      // 2. 关键点：监听数据接收事件
      httpRequest.on('dataReceive', (data: ArrayBuffer) => {
        try {
          // 修复：ArrayBuffer 转为 Uint8Array
          const textDecoder = new util.TextDecoder('utf-8');
          const chunk: string = textDecoder.decode(new Uint8Array(data));

          console.debug(`[流式响应] 收到数据块: ${chunk.length} 字节`);

          // 处理SSE格式数据(data:开头的行)
          const lines: string[] = chunk.split('\n');

          for (const line of lines) {
            if (!line.trim() || !line.startsWith('data: ')) continue;

            const jsonStr: string = line.substring(6).trim();

            if (jsonStr === '[DONE]') {
              console.info('[流式响应] 收到完成标记 [DONE]');
              onComplete && onComplete();
              return;
            }

            try {
              const parsedChunk: StreamChunk = JSON.parse(jsonStr) as StreamChunk;
              if (parsedChunk.choices?.length > 0 &&
                parsedChunk.choices[0].delta?.content) {
                const content: string = parsedChunk.choices[0].delta.content as string;
                fullResponse += content;
                console.debug(`[流式响应] 解析内容: "${content}"，累计长度: ${fullResponse.length}`);
                onUpdate && onUpdate(fullResponse);
              }
            } catch (e) {
              console.error(`[流式响应] 解析JSON失败: ${String(e)}`);
            }
          }
        } catch (e) {
          console.error(`[流式响应] 处理数据块错误: ${String(e)}`);
        }
      });

      // 3. 监听数据接收结束事件
      httpRequest.on('dataEnd', () => {
        console.info('[流式响应] 数据接收完毕');
        if (fullResponse) {
          onComplete && onComplete();
        }
      });

      // 4. 发起流式请求
      httpRequest.requestInStream(
        `${DeepSeekService.BASE_URL}/chat/completions`,
        {
          method: http.RequestMethod.POST,
          header: header,
          extraData: JSON.stringify(requestBody),
          connectTimeout: 60000,
          readTimeout: 60000
        }
      ).then((responseCode: number) => {
        // 修复：使用 number 类型而不是 HttpResponseSuccess
        console.info(`[流式响应] 请求已发送，状态码: ${responseCode}`);
        if (responseCode !== 200) {
          onError && onError(new Error(`HTTP错误: ${responseCode}`));
        }
      }).catch((err: BusinessError | Error) => {
        console.error(`[流式响应] 请求失败: ${JSON.stringify(err)}`);
        onError && onError(new Error(`请求失败: ${(err as Error).message || JSON.stringify(err)}`));
      });

    } catch (error) {
      console.error(`[流式响应] 捕获到错误: ${String(error)}`);
      onError && onError(error as Error);
    }

    // 返回取消函数
    return () => {
      console.info('[流式响应] 取消请求');
      httpRequest.off('headersReceive');
      httpRequest.off('dataReceive');
      httpRequest.off('dataEnd');
      httpRequest.destroy();
    };
  }
}