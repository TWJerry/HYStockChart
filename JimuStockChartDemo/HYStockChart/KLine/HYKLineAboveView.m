//
//  HYKLineView.m
//  JimuStockChartDemo
//
//  Created by jimubox on 15/5/4.
//  Copyright (c) 2015年 jimubox. All rights reserved.
//

#import "HYKLineAboveView.h"
#import "HYStockChartConstant.h"
#import "HYStockModel.h"
#import "HYKLine.h"
#import "HYKeyValueObserver.h"
#import "Masonry.h"
#import "HYStockChartGloablVariable.h"

@interface HYKLineAboveView ()

@property(nonatomic,strong) NSMutableArray *needDrawStockModels;

@property(nonatomic,strong) NSMutableArray *needDrawKLineModels;

@property(nonatomic,assign) NSUInteger needDrawStockStartIndex;

@property(nonatomic,assign,readonly) CGFloat startXPosition;

@property(nonatomic,assign) CGFloat oldContentOffsetX;

@property(nonatomic,assign) CGFloat oldScale;


@end

@implementation HYKLineAboveView

-(instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.needDrawStockModels = [NSMutableArray array];
        self.needDrawKLineModels = [NSMutableArray array];
        _needDrawStockStartIndex = 0;
        self.oldContentOffsetX = 0;
        self.oldScale = 0;
        self.backgroundColor = [UIColor whiteColor];
    }
    return self;
}

#pragma mark - 绘图相关方法
#pragma mark drawRect方法
- (void)drawRect:(CGRect)rect {
    if (!self.stockModels) {
        return;
    }
    //先提取需要展示的stockModel
    [self private_extractNeedDrawModels];
    //将stockModel转换成坐标模型
    NSArray *kLineModels = [self private_convertToKLineModelWithStockModels:self.needDrawStockModels];
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextClearRect(context, rect);
    CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextFillRect(context, rect);
    HYKLine *kLine = [[HYKLine alloc] initWithContext:context];
    kLine.maxY = HYStockChartAboveViewMaxY;
    NSInteger idx = 0;
    for (HYKLineModel *kLineModel in kLineModels) {
        kLine.kLineModel = kLineModel;
        kLine.stockModel = self.needDrawStockModels[idx];
        if (idx%4 == 0) {
            kLine.isNeedDrawDate = YES;
        }
        [kLine draw];
        idx++;
    }
    [super drawRect:rect];
}

#pragma mark 重新设置相关变量，然后绘图
-(void)drawAboveView
{
    if (!self.stockModels) {
        return;
    }
    //间接调用drawRect方法
    [self setNeedsDisplay];
}

#pragma mark - set&get方法
#pragma mark startXPosition的get方法
-(CGFloat)startXPosition
{
    CGFloat lineGap = [HYStockChartGloablVariable kLineGap];
    CGFloat lineWidth = [HYStockChartGloablVariable kLineWidth];
    NSInteger leftArrCount = self.needDrawStockStartIndex;
    CGFloat startXPosition = (leftArrCount+1)*lineGap + leftArrCount*lineWidth+lineWidth/2;
    return startXPosition;
}

#pragma mark needDrawStockStartIndex的get方法
-(NSUInteger)needDrawStockStartIndex
{
    CGFloat lineGap = [HYStockChartGloablVariable kLineGap];
    CGFloat lineWidth = [HYStockChartGloablVariable kLineWidth];
    CGFloat scrollViewOffsetX = self.scrollView.contentOffset.x < 0 ? 0 : self.scrollView.contentOffset.x;
    NSUInteger leftArrCount = ABS(scrollViewOffsetX - lineGap)/(lineWidth+lineGap);
    _needDrawStockStartIndex = leftArrCount;
    return _needDrawStockStartIndex;
}

#pragma mark stockModels的set方法
-(void)setStockModels:(NSArray *)stockModels
{
    _stockModels = stockModels;
    [self updateAboveViewWidth];
}

#pragma mark - 公有方法
#pragma mark 更新自身view的宽度
-(void)updateAboveViewWidth
{
    //根据stockModels个数和间隙以及K线的宽度算出self的宽度,设置contentSize
    CGFloat kLineViewWidth = self.stockModels.count * [HYStockChartGloablVariable kLineWidth] + (self.stockModels.count + 1) * [HYStockChartGloablVariable kLineGap]+10;
    [self mas_updateConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(@(kLineViewWidth));
    }];
    [self layoutIfNeeded];
    //更新scrollView的contentSize
    self.scrollView.contentSize = CGSizeMake(kLineViewWidth, self.scrollView.contentSize.height);
}


#pragma mark 根据原始的x的位置获得精确的X的位置
-(CGFloat)getRightXPositionWithOriginXPosition:(CGFloat)originXPosition
{
    CGFloat xPositionInAboveView = originXPosition + self.scrollView.contentOffset.x - 10;
    NSInteger startIndex = (NSInteger)((xPositionInAboveView-self.startXPosition) / ([HYStockChartGloablVariable kLineGap]+[HYStockChartGloablVariable kLineWidth]));
    NSInteger arrCount = self.needDrawKLineModels.count;
    for (NSInteger index = startIndex > 0 ? startIndex-1 : 0; index < arrCount; ++index) {
        HYKLineModel *kLineModel = self.needDrawKLineModels[index];
        CGFloat minX = kLineModel.highPoint.x - ([HYStockChartGloablVariable kLineGap]+[HYStockChartGloablVariable kLineWidth])/2;
        CGFloat maxX = kLineModel.highPoint.x + ([HYStockChartGloablVariable kLineGap]+[HYStockChartGloablVariable kLineWidth])/2;
        if (xPositionInAboveView > minX && xPositionInAboveView < maxX) {
            if (self.delegate && [self.delegate respondsToSelector:@selector(kLineAboveViewLongPressKLineModel:)]) {
                [self.delegate kLineAboveViewLongPressKLineModel:self.needDrawStockModels[index]];
            }
            return kLineModel.highPoint.x - self.scrollView.contentOffset.x+[HYStockChartGloablVariable kLineWidth]/2-[HYStockChartGloablVariable kLineGap];
        }
    }
    return 0;
}


#pragma mark - 私有方法
#pragma mark 提取需要绘制的数组
-(NSArray *)private_extractNeedDrawModels
{
    CGFloat lineGap = [HYStockChartGloablVariable kLineGap];
    CGFloat lineWidth = [HYStockChartGloablVariable kLineWidth];
    
    //数组个数
    CGFloat scrollViewWidth = self.scrollView.frame.size.width;
    CGFloat needDrawKLineCount = (scrollViewWidth - lineGap)/(lineGap+lineWidth);
    
    //起始位置
    NSInteger needDrawKLineStartIndex = self.needDrawStockStartIndex;
    
    [self.needDrawStockModels removeAllObjects];
    if ((needDrawKLineStartIndex + needDrawKLineCount) < self.stockModels.count) {
        [self.needDrawStockModels addObjectsFromArray:[self.stockModels subarrayWithRange:NSMakeRange(needDrawKLineStartIndex, needDrawKLineCount)]];
    }else{
        [self.needDrawStockModels addObjectsFromArray:[self.stockModels subarrayWithRange:NSMakeRange(needDrawKLineStartIndex, self.stockModels.count-needDrawKLineStartIndex)]];
    }
    return self.needDrawStockModels;
}

#pragma mark 将stockModel模型转换成KLine模型
-(NSArray *)private_convertToKLineModelWithStockModels:(NSArray *)stockModels
{
    //算得最小单位
    HYStockModel *firstModel = (HYStockModel *)[stockModels firstObject];
    CGFloat minAssert = firstModel.low;
    CGFloat maxAssert = firstModel.high;
    for (HYStockModel *stockModel in stockModels) {
        if (stockModel.high > maxAssert) {
            maxAssert = stockModel.high;
        }
        if (stockModel.low < minAssert) {
            minAssert = stockModel.low;
        }
    }
    CGFloat minY = HYStockChartAboveViewMinY;
    CGFloat maxY = HYStockChartAboveViewMaxY;
    CGFloat unitValue = (maxAssert - minAssert)/(maxY - minY);

    [self.needDrawKLineModels removeAllObjects];
    
    NSInteger stockModelsCount = stockModels.count;
    for (NSInteger idx = 0; idx < stockModelsCount; ++idx) {
        HYStockModel *stockModel = stockModels[idx];
        CGFloat xPosition = self.startXPosition + idx*([HYStockChartGloablVariable kLineWidth]+[HYStockChartGloablVariable kLineGap]);
        CGPoint openPoint = CGPointMake(xPosition, ABS(maxY - (stockModel.open-minAssert)/unitValue));
        
        CGFloat closePointY = ABS(maxY - (stockModel.close-minAssert)/unitValue);
        if (ABS(closePointY - openPoint.y) < HYStockChartKLineMinWidth) {
            if (openPoint.y > closePointY) {
                openPoint.y = closePointY+HYStockChartKLineMinWidth;
            }else if (openPoint.y < closePointY){
                closePointY = openPoint.y + HYStockChartKLineMinWidth;
            }else{
                if (idx > 0) {
                    HYStockModel *preStockModel = stockModels[idx-1];
                    if (stockModel.open > preStockModel.close) {
                        openPoint.y = closePointY + HYStockChartKLineMinWidth;
                    }else{
                        closePointY = openPoint.y + HYStockChartKLineMinWidth;
                    }
                }else if(idx+1 < stockModelsCount){
                    HYStockModel *subStockModel = stockModels[idx+1];
                    if (stockModel.close < subStockModel.open) {
                        openPoint.y = closePointY + HYStockChartKLineMinWidth;
                    }else{
                        closePointY = openPoint.y + HYStockChartKLineMinWidth;
                    }
                }
            }
        }
        CGPoint closePoint = CGPointMake(xPosition, closePointY);
        CGPoint highPoint = CGPointMake(xPosition, ABS(maxY - (stockModel.high-minAssert)/unitValue));
        CGPoint lowPoint = CGPointMake(xPosition, ABS(maxY - (stockModel.low-minAssert)/unitValue));
        HYKLineModel *kLineModel = [HYKLineModel modelWithOpen:openPoint close:closePoint high:highPoint low:lowPoint];
        [self.needDrawKLineModels addObject:kLineModel];
    }
    //执行代理方法
    if (self.delegate) {
        if ([self.delegate respondsToSelector:@selector(kLineAboveViewCurrentMaxPrice:minPrice:)]) {
            [self.delegate kLineAboveViewCurrentMaxPrice:maxAssert minPrice:minAssert];
        }
        if ([self.delegate respondsToSelector:@selector(kLineAboveViewNeedDrawKLineModels:)]) {
            [self.delegate kLineAboveViewNeedDrawKLineModels:self.needDrawKLineModels];
        }
    }
    return self.needDrawKLineModels;
}

#pragma mark 添加所有事件监听的方法
-(void)private_addAllEventListenr
{
    //用KVO监听scrollView的状态改变
    [_scrollView addObserver:self forKeyPath:HYStockChartContentOffsetKey options:NSKeyValueObservingOptionNew context:nil];
}


#pragma mark - 系统方法
#pragma mark 已经添加到父view的方法
-(void)didMoveToSuperview
{
    _scrollView = (UIScrollView *)self.superview;
    [self private_addAllEventListenr];
    [super didMoveToSuperview];
}

#pragma mark KVO监听实现的方法
-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:HYStockChartContentOffsetKey]) {
        CGFloat difValue = ABS(self.scrollView.contentOffset.x - self.oldContentOffsetX);
        if (difValue >= ([HYStockChartGloablVariable kLineGap]+[HYStockChartGloablVariable kLineWidth])) {
            self.oldContentOffsetX = self.scrollView.contentOffset.x;
            [self drawAboveView];
        }
    }
}

#pragma mark - 垃圾回收方法
#pragma mark dealloc方法
-(void)dealloc
{
    [_scrollView removeObserver:self forKeyPath:HYStockChartContentOffsetKey];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
