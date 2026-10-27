// The transcendental functions of Math used by the games, computed in plain JavaScript: the same result, to the last
// bit, on every browser and every processor. Math.sin, Math.pow... of the browsers differ in the last bit between
// engines (V8, JavaScriptCore, SpiderMonkey) and even between builds of one engine (Chrome x86 / ARM): a replay is
// chaotic (a bit of difference in an angle, and a jump misses its wheel 1000 frames later), so a game recorded on a
// phone could not be replayed on the server. Ports of fdlibm (as in V8 src/base/ieee754.cc, without the fused
// multiply-adds some compilers put in): only + - * / and sqrt, which IEEE 754 makes exact.
//
// build-games.mjs points Math.sin, Math.cos, Math.atan2, Math.pow, Math.acos, Math.exp and Math.log of the games to
// __kadoMath (esbuild define + inject). They call the browser until the game says otherwise: kado.ReplayManager turns
// the exact functions on for a live game (replay version 5) and for the replays recorded with them, the older replays
// keep the functions of the browser they were recorded with.

// (through another name: the define of esbuild would point Math.sin of this file to __kadoMath too)
const M = Math
const native = { sin: M.sin, cos: M.cos, atan2: M.atan2, pow: M.pow, acos: M.acos, exp: M.exp, log: M.log }
const sqrt = M.sqrt
let exact = false

// the words of a double (little endian, like every browser)
const F64 = new Float64Array(1)
const U32 = new Uint32Array(F64.buffer)
const high = (x) => { F64[0] = x; return U32[1] | 0 }
const low = (x) => { F64[0] = x; return U32[0] }
const fromWords = (h, l) => { U32[1] = h; U32[0] = l; return F64[0] }
const withLow0 = (x) => { F64[0] = x; U32[0] = 0; return F64[0] }
const withHigh = (x, h) => { F64[0] = x; U32[1] = h; return F64[0] }

// sin / cos: kernels on [-pi/4, pi/4], x + y the reduced argument

const S1 = -1.66666666666666324348e-01, S2 = 8.33333333332248946124e-03, S3 = -1.98412698298579493134e-04,
  S4 = 2.75573137070700676789e-06, S5 = -2.50507602534068634195e-08, S6 = 1.58969099521155010221e-10

function kernelSin(x, y, iy) {
  const ix = high(x) & 0x7fffffff
  if (ix < 0x3e400000 && (x | 0) === 0) return x
  const z = x * x, v = z * x, r = S2 + z * (S3 + z * (S4 + z * (S5 + z * S6)))
  if (iy === 0) return x + v * (S1 + z * r)
  return x - ((z * (0.5 * y - v * r) - y) - v * S1)
}

const C1 = 4.16666666666666019037e-02, C2 = -1.38888888888741095749e-03, C3 = 2.48015872894767294178e-05,
  C4 = -2.75573143513906633035e-07, C5 = 2.08757232129817482790e-09, C6 = -1.13596475577881948265e-11

function kernelCos(x, y) {
  const ix = high(x) & 0x7fffffff
  if (ix < 0x3e400000 && (x | 0) === 0) return 1
  const z = x * x, r = z * (C1 + z * (C2 + z * (C3 + z * (C4 + z * (C5 + z * C6)))))
  if (ix < 0x3fd33333) return 1 - (0.5 * z - (z * r - x * y))
  const qx = ix > 0x3fe90000 ? 0.28125 : fromWords(ix - 0x00200000, 0)
  const hz = 0.5 * z - qx, a = 1 - qx
  return a - (hz - (z * r - x * y))
}

const invpio2 = 6.36619772367581382433e-01, pio2_1 = 1.57079632673412561417e+00, pio2_1t = 6.07710050650619224932e-11,
  pio2_2 = 6.07710050630396597660e-11, pio2_2t = 2.02226624879595063154e-21, pio2_3 = 2.02226624871116645580e-21,
  pio2_3t = 8.47842766036889956997e-32
const npio2_hw = [0x3FF921FB, 0x400921FB, 0x4012D97C, 0x401921FB, 0x401F6A7A, 0x4022D97C, 0x4025FDBB, 0x402921FB,
  0x402C463A, 0x402F6A7A, 0x4031475C, 0x4032D97C, 0x40346B9C, 0x4035FDBB, 0x40378FDB, 0x403921FB, 0x403AB41B,
  0x403C463A, 0x403DD85A, 0x403F6A7A, 0x40407E4C, 0x4041475C, 0x4042106C, 0x4042D97C, 0x4043A28C, 0x40446B9C,
  0x404534AC, 0x4045FDBB, 0x4046C6CB, 0x40478FDB, 0x404858EB, 0x404921FB]
const reduced = [0, 0]

// x reduced modulo pi/2 into reduced[0] + reduced[1], returns the quadrant, for |x| <= 2^20 * pi/2 (see bigAngle)
function remPio2(x) {
  const hx = high(x), ix = hx & 0x7fffffff
  if (ix < 0x4002d97c) { // |x| < 3pi/4
    if (hx > 0) {
      let z = x - pio2_1
      if (ix !== 0x3ff921fb) { reduced[0] = z - pio2_1t; reduced[1] = (z - reduced[0]) - pio2_1t }
      else { z -= pio2_2; reduced[0] = z - pio2_2t; reduced[1] = (z - reduced[0]) - pio2_2t }
      return 1
    }
    let z = x + pio2_1
    if (ix !== 0x3ff921fb) { reduced[0] = z + pio2_1t; reduced[1] = (z - reduced[0]) + pio2_1t }
    else { z += pio2_2; reduced[0] = z + pio2_2t; reduced[1] = (z - reduced[0]) + pio2_2t }
    return -1
  }
  const t = Math.abs(x)
  const fn = (t * invpio2 + 0.5) | 0
  let r = t - fn * pio2_1, w = fn * pio2_1t
  if (fn < 32 && ix !== npio2_hw[fn - 1]) {
    reduced[0] = r - w
  } else {
    const j = ix >> 20
    reduced[0] = r - w
    let i = j - ((high(reduced[0]) >> 20) & 0x7ff)
    if (i > 16) { // 2nd iteration, good to 118 bits
      let t2 = r
      w = fn * pio2_2
      r = t2 - w
      w = fn * pio2_2t - ((t2 - r) - w)
      reduced[0] = r - w
      i = j - ((high(reduced[0]) >> 20) & 0x7ff)
      if (i > 49) { // 3rd iteration, 151 bits
        t2 = r
        w = fn * pio2_3
        r = t2 - w
        w = fn * pio2_3t - ((t2 - r) - w)
        reduced[0] = r - w
      }
    }
  }
  reduced[1] = (r - reduced[0]) - w
  if (hx < 0) {
    reduced[0] = -reduced[0]
    reduced[1] = -reduced[1]
    return -fn
  }
  return fn
}

// beyond 2^20 * pi/2, fdlibm reduces with __kernel_rem_pio2 (not ported): here modulo the double nearest 2 pi (%
// is exact), less precise but still the same everywhere (no game turns that far)
const TWO_PI = 6.283185307179586
const bigAngle = (ix) => ix > 0x413921fb && ix < 0x7ff00000

export function sin(x) {
  let ix = high(x) & 0x7fffffff
  if (bigAngle(ix)) {
    x %= TWO_PI
    ix = high(x) & 0x7fffffff
  }
  if (ix <= 0x3fe921fb) return kernelSin(x, 0, 0)
  if (ix >= 0x7ff00000) return x - x
  switch (remPio2(x) & 3) {
    case 0: return kernelSin(reduced[0], reduced[1], 1)
    case 1: return kernelCos(reduced[0], reduced[1])
    case 2: return -kernelSin(reduced[0], reduced[1], 1)
    default: return -kernelCos(reduced[0], reduced[1])
  }
}

export function cos(x) {
  let ix = high(x) & 0x7fffffff
  if (bigAngle(ix)) {
    x %= TWO_PI
    ix = high(x) & 0x7fffffff
  }
  if (ix <= 0x3fe921fb) return kernelCos(x, 0)
  if (ix >= 0x7ff00000) return x - x
  switch (remPio2(x) & 3) {
    case 0: return kernelCos(reduced[0], reduced[1])
    case 1: return -kernelSin(reduced[0], reduced[1], 1)
    case 2: return -kernelCos(reduced[0], reduced[1])
    default: return kernelSin(reduced[0], reduced[1], 1)
  }
}

// atan / atan2

const atanhi = [4.63647609000806093515e-01, 7.85398163397448278999e-01, 9.82793723247329054082e-01, 1.57079632679489655800e+00]
const atanlo = [2.26987774529616870924e-17, 3.06161699786838301793e-17, 1.39033110312309984516e-17, 6.12323399573676603587e-17]
const aT = [3.33333333333329318027e-01, -1.99999999998764832476e-01, 1.42857142725034663711e-01, -1.11111104054623557880e-01,
  9.09088713343650656196e-02, -7.69187620504482999495e-02, 6.66107313738753120669e-02, -5.83357013379057348645e-02,
  4.97687799461593236017e-02, -3.65315727442169155270e-02, 1.62858201153657823623e-02]

function atan(x) {
  const hx = high(x), ix = hx & 0x7fffffff
  let id
  if (ix >= 0x44100000) { // |x| >= 2^66
    if (ix > 0x7ff00000 || (ix === 0x7ff00000 && low(x) !== 0)) return x + x
    return hx > 0 ? atanhi[3] + atanlo[3] : -atanhi[3] - atanlo[3]
  }
  if (ix < 0x3fdc0000) { // |x| < 0.4375
    if (ix < 0x3e400000) return x
    id = -1
  } else {
    x = Math.abs(x)
    if (ix < 0x3ff30000) {
      if (ix < 0x3fe60000) { id = 0; x = (2 * x - 1) / (2 + x) } else { id = 1; x = (x - 1) / (x + 1) }
    } else if (ix < 0x40038000) { id = 2; x = (x - 1.5) / (1 + 1.5 * x) } else { id = 3; x = -1 / x }
  }
  const z = x * x, w = z * z
  const s1 = z * (aT[0] + w * (aT[2] + w * (aT[4] + w * (aT[6] + w * (aT[8] + w * aT[10])))))
  const s2 = w * (aT[1] + w * (aT[3] + w * (aT[5] + w * (aT[7] + w * aT[9]))))
  if (id < 0) return x - x * (s1 + s2)
  const r = atanhi[id] - ((x * (s1 + s2) - atanlo[id]) - x)
  return hx < 0 ? -r : r
}

const tiny = 1.0e-300, pi_o_4 = 7.8539816339744827900e-01, pi_o_2 = 1.5707963267948965580e+00,
  pi = 3.1415926535897931160e+00, pi_lo = 1.2246467991473531772e-16

export function atan2(y, x) {
  if (x !== x || y !== y) return x + y
  const hx = high(x), ix = hx & 0x7fffffff, lx = low(x), hy = high(y), iy = hy & 0x7fffffff, ly = low(y)
  if (hx === 0x3ff00000 && lx === 0) return atan(y) // x = 1
  let m = ((hy >>> 31) & 1) | ((hx >>> 30) & 2) // 2 * sign(x) + sign(y)
  if ((iy | ly) === 0) { // y = 0
    switch (m) {
      case 0: case 1: return y
      case 2: return pi + tiny
      default: return -pi - tiny
    }
  }
  if ((ix | lx) === 0) return hy < 0 ? -pi_o_2 - tiny : pi_o_2 + tiny // x = 0
  if (ix === 0x7ff00000) { // x = inf
    if (iy === 0x7ff00000) {
      switch (m) {
        case 0: return pi_o_4 + tiny
        case 1: return -pi_o_4 - tiny
        case 2: return 3 * pi_o_4 + tiny
        default: return -3 * pi_o_4 - tiny
      }
    }
    switch (m) {
      case 0: return 0
      case 1: return -0
      case 2: return pi + tiny
      default: return -pi - tiny
    }
  }
  if (iy === 0x7ff00000) return hy < 0 ? -pi_o_2 - tiny : pi_o_2 + tiny // y = inf
  const k = (iy - ix) >> 20
  let z
  if (k > 60) { // |y / x| > 2^60: +-pi/2 (the fix of FreeBSD, in V8 too)
    z = pi_o_2 + 0.5 * pi_lo
    m &= 1
  } else if (hx < 0 && k < -60) z = 0 // |y| / x < -2^60
  else z = atan(Math.abs(y / x))
  switch (m) {
    case 0: return z
    case 1: return -z
    case 2: return pi - (z - pi_lo)
    default: return (z - pi_lo) - pi
  }
}

// acos

const pio2_hi = 1.57079632679489655800e+00, pio2_lo = 6.12323399573676603587e-17,
  pS0 = 1.66666666666666657415e-01, pS1 = -3.25565818622400915405e-01, pS2 = 2.01212532134862925881e-01,
  pS3 = -4.00555345006794114027e-02, pS4 = 7.91534994289814532176e-04, pS5 = 3.47933107596021167570e-05,
  qS1 = -2.40339491173441421878e+00, qS2 = 2.02094576023350569471e+00, qS3 = -6.88283971605453293030e-01,
  qS4 = 7.70381505559019352791e-02

const acosP = (z) => z * (pS0 + z * (pS1 + z * (pS2 + z * (pS3 + z * (pS4 + z * pS5)))))
const acosQ = (z) => 1 + z * (qS1 + z * (qS2 + z * (qS3 + z * qS4)))

export function acos(x) {
  const hx = high(x), ix = hx & 0x7fffffff
  if (ix >= 0x3ff00000) { // |x| >= 1
    if (((ix - 0x3ff00000) | low(x)) === 0) return hx > 0 ? 0 : pi + 2 * pio2_lo
    return (x - x) / (x - x) // NaN
  }
  if (ix < 0x3fe00000) { // |x| < 0.5
    if (ix <= 0x3c600000) return pio2_hi + pio2_lo
    const z = x * x
    return pio2_hi - (x - (pio2_lo - x * (acosP(z) / acosQ(z))))
  }
  if (hx < 0) { // x < -0.5
    const z = (1 + x) * 0.5, s = sqrt(z)
    const w = (acosP(z) / acosQ(z)) * s - pio2_lo
    return pi - 2 * (s + w)
  }
  const z = (1 - x) * 0.5, s = sqrt(z), df = withLow0(s)
  const c = (z - df * df) / (s + df)
  const w = (acosP(z) / acosQ(z)) * s + c
  return 2 * (df + w)
}

// exp

const o_threshold = 7.09782712893383973096e+02, u_threshold = -7.45133219101941108420e+02,
  ln2HI = [6.93147180369123816490e-01, -6.93147180369123816490e-01],
  ln2LO = [1.90821492927058770002e-10, -1.90821492927058770002e-10], invln2 = 1.44269504088896338700e+00,
  P1 = 1.66666666666666019037e-01, P2 = -2.77777777770155933842e-03, P3 = 6.61375632143793436117e-05,
  P4 = -1.65339022054652515390e-06, P5 = 4.13813679705723846039e-08, huge = 1.0e+300,
  twom1000 = 9.33263618503218878990e-302, two1023 = 8.988465674311579539e307

export function exp(x) {
  // (fdlibm is 1 ulp off there: V8 gives Math.E too)
  if (x === 1) return 2.718281828459045
  let hx = high(x)
  const xsb = (hx >>> 31) & 1
  hx &= 0x7fffffff
  let hi = 0, lo = 0, k = 0
  if (hx >= 0x40862e42) { // |x| >= 709.78
    if (hx >= 0x7ff00000) {
      if (((hx & 0xfffff) | low(x)) !== 0) return x + x // NaN
      return xsb === 0 ? x : 0
    }
    if (x > o_threshold) return huge * huge
    if (x < u_threshold) return twom1000 * twom1000
  }
  if (hx > 0x3fd62e42) { // |x| > 0.5 ln2
    if (hx < 0x3ff0a2b2) { // |x| < 1.5 ln2
      hi = x - ln2HI[xsb]
      lo = ln2LO[xsb]
      k = 1 - xsb - xsb
    } else {
      k = (invln2 * x + (xsb ? -0.5 : 0.5)) | 0
      hi = x - k * ln2HI[0]
      lo = k * ln2LO[0]
    }
    x = hi - lo
  } else if (hx < 0x3e300000) { // |x| < 2^-28
    if (huge + x > 1) return 1 + x
  }
  const t = x * x
  const c = x - t * (P1 + t * (P2 + t * (P3 + t * (P4 + t * P5))))
  if (k === 0) return 1 - ((x * c) / (c - 2) - x)
  const y = 1 - ((lo - (x * c) / (2 - c)) - hi)
  if (k >= -1021) {
    if (k === 1024) return y * 2 * two1023
    return y * fromWords((0x3ff00000 + (k << 20)) >>> 0, 0)
  }
  return y * fromWords((0x3ff00000 + ((k + 1000) << 20)) >>> 0, 0) * twom1000
}

// log

const ln2_hi = 6.93147180369123816490e-01, ln2_lo = 1.90821492927058770002e-10, two54 = 1.80143985094819840000e+16,
  Lg1 = 6.666666666666735130e-01, Lg2 = 3.999999999940941908e-01, Lg3 = 2.857142874366239149e-01,
  Lg4 = 2.222219843214978396e-01, Lg5 = 1.818357216161805012e-01, Lg6 = 1.531383769920937332e-01,
  Lg7 = 1.479819860511658591e-01

export function log(x) {
  let hx = high(x)
  const lx = low(x)
  let k = 0
  if (hx < 0x00100000) { // x < 2^-1022
    if (((hx & 0x7fffffff) | lx) === 0) return -Infinity
    if (hx < 0) return NaN
    k -= 54
    x *= two54
    hx = high(x)
  }
  if (hx >= 0x7ff00000) return x + x
  k += (hx >> 20) - 1023
  hx &= 0x000fffff
  const i = (hx + 0x95f64) & 0x100000
  x = withHigh(x, (hx | (i ^ 0x3ff00000)) >>> 0) // x or x / 2
  k += i >> 20
  const f = x - 1
  if ((0x000fffff & (2 + hx)) < 3) { // -2^-20 <= f < 2^-20
    if (f === 0) return k === 0 ? 0 : k * ln2_hi + k * ln2_lo
    const R = f * f * (0.5 - 0.33333333333333333 * f)
    return k === 0 ? f - R : k * ln2_hi - ((R - k * ln2_lo) - f)
  }
  const s = f / (2 + f), dk = k, z = s * s, w = z * z
  const t1 = w * (Lg2 + w * (Lg4 + w * Lg6))
  const t2 = z * (Lg1 + w * (Lg3 + w * (Lg5 + w * Lg7)))
  const R = t2 + t1
  if (((hx - 0x6147a) | (0x6b851 - hx)) > 0) {
    const hfsq = 0.5 * f * f
    if (k === 0) return f - (hfsq - s * (hfsq + R))
    return dk * ln2_hi - ((hfsq - (s * (hfsq + R) + dk * ln2_lo)) - f)
  }
  if (k === 0) return f - s * (f - R)
  return dk * ln2_hi - ((s * (f - R) - dk * ln2_lo) - f)
}

// pow

const bp = [1, 1.5], dp_h = [0, 5.84962487220764160156e-01], dp_l = [0, 1.35003920212974897128e-08],
  two53 = 9007199254740992.0,
  L1 = 5.99999999999994648725e-01, L2 = 4.28571428578550184252e-01, L3 = 3.33333329818377432918e-01,
  L4 = 2.72728123808534006489e-01, L5 = 2.30660745775561754067e-01, L6 = 2.06975017800338417784e-01,
  lg2 = 6.93147180559945286227e-01, lg2_h = 6.93147182464599609375e-01, lg2_l = -1.90465429995776804525e-09,
  ovt = 8.0085662595372944372e-17,
  cp = 9.61796693925975554329e-01, cp_h = 9.61796700954437255859e-01, cp_l = -7.02846165095275826516e-09,
  ivln2 = 1.44269504088896338700e+00, ivln2_h = 1.44269502162933349609e+00, ivln2_l = 1.92596299112661746887e-08,
  twom54 = 5.55111512312578270212e-17

// x * 2^n, x a double near 1 (one rounding, like fdlibm's scalbn)
function scalbn(x, n) {
  const hx = high(x)
  let k = ((hx & 0x7ff00000) >> 20) + n
  if (k > 0x7fe) return huge * (x < 0 ? -huge : huge)
  if (k > 0) return withHigh(x, ((hx & 0x800fffff) | (k << 20)) >>> 0)
  if (k <= -54) return tiny * (x < 0 ? -tiny : tiny)
  k += 54
  return withHigh(x, ((hx & 0x800fffff) | (k << 20)) >>> 0) * twom54
}

export function pow(x, y) {
  const hx = high(x), lx = low(x), hy = high(y), ly = low(y)
  let ix = hx & 0x7fffffff
  const iy = hy & 0x7fffffff

  if ((iy | ly) === 0) return 1 // y = +-0
  if (ix > 0x7ff00000 || (ix === 0x7ff00000 && lx !== 0) || iy > 0x7ff00000 || (iy === 0x7ff00000 && ly !== 0)) return x + y // NaN

  // x < 0: y odd integer (1), even integer (2), not an integer (0)
  let yisint = 0
  if (hx < 0) {
    if (iy >= 0x43400000) yisint = 2 // |y| >= 2^53: even
    else if (iy >= 0x3ff00000) {
      const k = (iy >> 20) - 0x3ff
      if (k > 20) {
        const j = ly >>> (52 - k)
        if (((j << (52 - k)) >>> 0) === ly) yisint = 2 - (j & 1)
      } else if (ly === 0) {
        const j = iy >> (20 - k)
        if ((j << (20 - k)) === iy) yisint = 2 - (j & 1)
      }
    }
  }

  if (ly === 0) {
    if (iy === 0x7ff00000) { // y = +-inf
      if (((ix - 0x3ff00000) | lx) === 0) return y - y // (-1)^+-inf: NaN
      if (ix >= 0x3ff00000) return hy >= 0 ? y : 0 // |x| > 1
      return hy < 0 ? -y : 0 // |x| < 1
    }
    if (iy === 0x3ff00000) return hy < 0 ? 1 / x : x // y = +-1
    if (hy === 0x40000000) return x * x // y = 2
    if (hy === 0x3fe00000 && hx >= 0) return sqrt(x) // y = 0.5, x >= +0
  }

  let ax = Math.abs(x)
  if (lx === 0 && (ix === 0x7ff00000 || ix === 0 || ix === 0x3ff00000)) { // x = +-0, +-inf, +-1
    let z = ax
    if (hy < 0) z = 1 / z
    if (hx < 0) {
      if (((ix - 0x3ff00000) | yisint) === 0) z = (z - z) / (z - z) // (-1)^non-int: NaN
      else if (yisint === 1) z = -z
    }
    return z
  }

  if (hx < 0 && yisint === 0) return (x - x) / (x - x) // (x < 0)^(non-int): NaN
  const s = hx < 0 && yisint === 1 ? -1 : 1 // sign of the result

  let t1, t2
  if (iy > 0x41e00000) { // |y| > 2^31
    if (iy > 0x43f00000) { // |y| > 2^64: overflow or underflow
      if (ix <= 0x3fefffff) return hy < 0 ? huge * huge : tiny * tiny
      return hy > 0 ? huge * huge : tiny * tiny
    }
    if (ix < 0x3fefffff) return hy < 0 ? s * huge * huge : s * tiny * tiny
    if (ix > 0x3ff00000) return hy > 0 ? s * huge * huge : s * tiny * tiny
    // |1 - x| tiny: log(x) by its series
    const t = ax - 1
    const w = (t * t) * (0.5 - t * (0.3333333333333333333333 - t * 0.25))
    const u = ivln2_h * t, v = t * ivln2_l - w * ivln2
    t1 = withLow0(u + v)
    t2 = v - (t1 - u)
  } else {
    let n = 0
    if (ix < 0x00100000) { // subnormal x
      ax *= two53
      n -= 53
      ix = high(ax)
    }
    n += (ix >> 20) - 0x3ff
    const j = ix & 0x000fffff
    ix = j | 0x3ff00000 // normalize ix
    let k
    if (j <= 0x3988e) k = 0 // |x| < sqrt(3/2)
    else if (j < 0xbb67a) k = 1 // |x| < sqrt(3)
    else { k = 0; n += 1; ix -= 0x00100000 }
    ax = withHigh(ax, ix >>> 0)

    // ss = s_h + s_l = (x - 1) / (x + 1) or (x - 1.5) / (x + 1.5)
    const u = ax - bp[k], v = 1 / (ax + bp[k]), ss = u * v
    const s_h = withLow0(ss)
    // t_h = ax + bp[k] high
    let t_h = fromWords((((ix >> 1) | 0x20000000) + 0x00080000 + (k << 18)) >>> 0, 0)
    let t_l = ax - (t_h - bp[k])
    const s_l = v * ((u - s_h * t_h) - s_h * t_l)
    // log(ax) / ln2
    let s2 = ss * ss
    let r = s2 * s2 * (L1 + s2 * (L2 + s2 * (L3 + s2 * (L4 + s2 * (L5 + s2 * L6)))))
    r += s_l * (s_h + ss)
    s2 = s_h * s_h
    t_h = withLow0(3 + s2 + r)
    t_l = r - ((t_h - 3) - s2)
    // u + v = ss * (1 + ...)
    const u2 = s_h * t_h, v2 = s_l * t_h + t_l * ss
    // 2 / (3 ln2) * (ss + ...)
    const p_h = withLow0(u2 + v2)
    const p_l = v2 - (p_h - u2)
    const z_h = cp_h * p_h, z_l = cp_l * p_h + p_l * cp + dp_l[k]
    // log2(ax) = (ss + ...) * 2 / (3 ln2) = n + dp_h + z_h + z_l
    const t = n
    t1 = withLow0(((z_h + z_l) + dp_h[k]) + t)
    t2 = z_l - (((t1 - t) - dp_h[k]) - z_h)
  }

  // (y1 + y2) * (t1 + t2)
  const y1 = withLow0(y)
  const p_l = (y - y1) * t1 + y * t2
  let p_h = y1 * t1
  let z = p_l + p_h
  let j = high(z)
  const i = low(z)
  if (j >= 0x40900000) { // z >= 1024
    if (((j - 0x40900000) | i) !== 0) return s * huge * huge
    if (p_l + ovt > z - p_h) return s * huge * huge
  } else if ((j & 0x7fffffff) >= 0x4090cc00) { // z <= -1075
    if (((j - 0xc090cc00) | i) !== 0) return s * tiny * tiny
    if (p_l <= z - p_h) return s * tiny * tiny
  }

  // 2^(p_h + p_l)
  const ii = j & 0x7fffffff
  let k = (ii >> 20) - 0x3ff
  let n = 0
  if (ii > 0x3fe00000) { // |z| > 0.5: n = [z + 0.5]
    n = j + (0x00100000 >> (k + 1))
    k = ((n & 0x7fffffff) >> 20) - 0x3ff // new k for n
    const t = fromWords((n & ~(0x000fffff >> k)) >>> 0, 0)
    n = ((n & 0x000fffff) | 0x00100000) >> (20 - k)
    if (j < 0) n = -n
    p_h -= t
  }
  let t = withLow0(p_l + p_h)
  const u = t * lg2_h, v = (p_l - (t - p_h)) * lg2 + t * lg2_l
  z = u + v
  const w = v - (z - u)
  t = z * z
  const t3 = z - t * (P1 + t * (P2 + t * (P3 + t * (P4 + t * P5))))
  const r = (z * t3) / (t3 - 2) - (w + z * w)
  z = 1 - (r - z)
  j = high(z) + (n << 20)
  if ((j >> 20) <= 0) z = scalbn(z, n) // subnormal output
  else z = withHigh(z, j >>> 0)
  return s * z
}

export const __kadoMath = {
  sin: (x) => (exact ? sin(+x) : native.sin(x)),
  cos: (x) => (exact ? cos(+x) : native.cos(x)),
  atan2: (y, x) => (exact ? atan2(+y, +x) : native.atan2(y, x)),
  pow: (x, y) => (exact ? pow(+x, +y) : native.pow(x, y)),
  acos: (x) => (exact ? acos(+x) : native.acos(x)),
  exp: (x) => (exact ? exp(+x) : native.exp(x)),
  log: (x) => (exact ? log(+x) : native.log(x)),
  // kado.ExactMath
  setExact(value) { exact = !!value },
  isExact() { return exact },
}
