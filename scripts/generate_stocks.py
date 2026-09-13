#!/usr/bin/env python3
"""
대한민국(KOSPI, KOSDAQ 전종목) 및 미국(NASDAQ 전종목 5,500+개)을
공식 및 실시간 증권 데이터 피드에서 완전 수집하여
assets/data/stocks_default.json 에 약 10,000개 전종목 데이터베이스를 구축하는 스크립트.
"""

import json
import os
import re
import urllib.request

# 주요 미국 종목 한글 별칭 매핑 (한국인 사용자 편의용)
KOREAN_NAMES_MAP = {
    "AAPL": "애플 (Apple)",
    "MSFT": "마이크로소프트 (Microsoft)",
    "NVDA": "엔비디아 (NVIDIA)",
    "GOOGL": "알파벳 A (Alphabet Class A)",
    "GOOG": "알파벳 C (Alphabet Class C)",
    "AMZN": "아마존 (Amazon)",
    "META": "메타 (Meta Platforms)",
    "TSLA": "테슬라 (Tesla)",
    "AVGO": "브로드컴 (Broadcom)",
    "AMD": "AMD (Advanced Micro Devices)",
    "INTC": "인텔 (Intel)",
    "QCOM": "퀄컴 (Qualcomm)",
    "NFLX": "넷플릭스 (Netflix)",
    "COST": "코스트코 (Costco Wholesale)",
    "PEP": "펩시코 (PepsiCo)",
    "CSCO": "시스코 시스템즈 (Cisco)",
    "TMUS": "티모바일 (T-Mobile)",
    "TXN": "텍사스 인스트루먼트 (TI)",
    "ADBE": "어도비 (Adobe)",
    "PLTR": "팔란티어 (Palantir)",
    "COIN": "코인베이스 (Coinbase)",
    "ARM": "ARM 홀딩스 (Arm)",
    "MU": "마이크론 (Micron)",
    "SMCI": "슈퍼마이크로 컴퓨터 (SMCI)",
    "QQQ": "Invesco QQQ Trust (나스닥100 ETF)",
    "TQQQ": "ProShares UltraPro QQQ (3x 나스닥)",
    "SQQQ": "ProShares UltraPro Short QQQ (-3x)",
    "SOXL": "Direxion Daily Semiconductor Bull 3X",
    "SOXS": "Direxion Daily Semiconductor Bear 3X",
    "NKE": "나이키 (Nike)",
    "DIS": "월트 디즈니 (Walt Disney)",
    "UBER": "우버 (Uber)",
    "ABNB": "에어비앤비 (Airbnb)",
    "SNOW": "스노우플레이크 (Snowflake)",
    "TSM": "TSMC",
    "BABA": "알리바바 (Alibaba)",
    "PANW": "팔로알토 네트웍스 (Palo Alto Networks)",
    "CRWD": "크라우드스트라이크 (CrowdStrike)",
    "MRVL": "마벨 테크놀로지 (Marvell)",
    "AMAT": "어플라이드 머티어리얼즈 (Applied Materials)",
    "LRCX": "램리서치 (Lam Research)",
    "ASML": "ASML 홀딩 (ASML)",
    "PDD": "핀둬둬 (PDD Holdings)",
    "MELI": "메르카도리브레 (MercadoLibre)",
    "INTU": "인튜이트 (Intuit)",
    "BKNG": "부킹 홀딩스 (Booking Holdings)",
    "MDLZ": "몬델리즈 (Mondelez)",
    "GILD": "길리어드 사이언스 (Gilead)",
    "ISRG": "인튜이티브 서지컬 (Intuitive Surgical)",
    "REGN": "리제네론 (Regeneron)",
    "VRTX": "버텍스 파마슈티컬 (Vertex)",
    "PYPL": "페이팔 (PayPal)",
    "MRNA": "모더나 (Moderna)",
    "ROKU": "로쿠 (Roku)",
    "HOOD": "로빈후드 (Robinhood)"
}

def fetch_korean_stocks(market_name):
    """
    KOSPI 또는 KOSDAQ 전종목 수집
    """
    url = f'https://finance.daum.net/api/quotes/stocks?market={market_name}'
    req = urllib.request.Request(url, headers={
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)',
        'Referer': 'https://finance.daum.net/'
    })
    try:
        content = urllib.request.urlopen(req, timeout=15).read().decode('utf-8')
        data = json.loads(content)
        items = data.get('data', [])
        stocks = []
        target_market = 'kospi' if market_name == 'KOSPI' else 'kosdaq'
        for item in items:
            symbol_code = item.get('symbolCode', '')
            name = item.get('name', '').strip()
            if symbol_code.startswith('A'):
                code = symbol_code[1:]
            else:
                code = symbol_code
            if code and name:
                stocks.append({
                    'code': code,
                    'name': name,
                    'market': target_market,
                })
        return stocks
    except Exception as e:
        print(f"Error fetching {market_name}: {e}")
        return []

def fetch_nasdaq_all_stocks():
    """
    NASDAQ 공식 상장 종목 전체 수집 (nasdaqlisted.txt)
    """
    url = 'http://www.nasdaqtrader.com/dynamic/SymDir/nasdaqlisted.txt'
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    try:
        content = urllib.request.urlopen(req, timeout=20).read().decode('utf-8')
        lines = content.strip().split('\n')
        stocks = []
        for line in lines[1:]:
            parts = line.split('|')
            if len(parts) >= 6:
                symbol = parts[0].strip()
                sec_name = parts[1].strip()
                is_test = parts[3].strip()

                if is_test == 'N' and symbol and sec_name and not symbol.startswith('File Creation'):
                    # 한국어 친화 이름이 있으면 병기, 없으면 원본 영문 회사명 사용
                    displayName = KOREAN_NAMES_MAP.get(symbol, f"{sec_name} ({symbol})")
                    stocks.append({
                        'code': symbol,
                        'name': displayName,
                        'market': 'nasdaq',
                    })
        return stocks
    except Exception as e:
        print(f"Error fetching NASDAQ: {e}")
        return []

def main():
    print("1. Fetching KOSPI full stock list...")
    kospi_stocks = fetch_korean_stocks('KOSPI')
    print(f"   -> {len(kospi_stocks)} KOSPI stocks fetched.")

    print("2. Fetching KOSDAQ full stock list...")
    kosdaq_stocks = fetch_korean_stocks('KOSDAQ')
    print(f"   -> {len(kosdaq_stocks)} KOSDAQ stocks fetched (including Olix).")

    print("3. Fetching NASDAQ official full stock list...")
    nasdaq_stocks = fetch_nasdaq_all_stocks()
    print(f"   -> {len(nasdaq_stocks)} NASDAQ stocks fetched.")

    # Deduplicate by (market, code)
    seen = set()
    combined = []

    for s in kospi_stocks + kosdaq_stocks + nasdaq_stocks:
        key = (s['market'], s['code'])
        if key not in seen:
            seen.add(key)
            combined.append(s)

    output_path = os.path.join(os.path.dirname(__file__), '..', 'assets', 'data', 'stocks_default.json')
    output_path = os.path.abspath(output_path)

    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(combined, f, ensure_ascii=False, indent=2)

    print(f"\n==========================================")
    print(f"Total stocks in database: {len(combined)}")
    print(f"  - KOSPI:  {sum(1 for s in combined if s['market'] == 'kospi')}")
    print(f"  - KOSDAQ: {sum(1 for s in combined if s['market'] == 'kosdaq')}")
    print(f"  - NASDAQ: {sum(1 for s in combined if s['market'] == 'nasdaq')}")
    print(f"Database saved to: {output_path}")
    print(f"==========================================")

if __name__ == '__main__':
    main()
