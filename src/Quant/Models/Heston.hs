{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE FlexibleInstances #-}


module Quant.Models.Heston (
    Heston (..)
) where

import Quant.YieldCurve
import Data.Random
import Control.Monad.State
import Quant.MonteCarlo
import Quant.ContingentClaim

-- | 'Heston' represents a Heston model (i.e. stochastic volatility).
data Heston = forall a b  . (YieldCurve a, YieldCurve b) => Heston {
    hestonInit       :: Double  -- ^ Initial asset level.
  , hestonV0         :: Double  -- ^ Initial variance
  , hestonVF         :: Double  -- ^ Mean-reversion variance
  , hestonLambda     :: Double  -- ^ Vol-vol
  , hestonCorrel     :: Double  -- ^ Correlation between processes
  , hestonMeanRev    :: Double  -- ^ Mean reversion speed
  , hestonForwardGen :: a       -- ^ 'YieldCurve' to generate forwards
  , hestonDisc       :: b }     -- ^ 'YieldCurve' to generate discounts

instance Discretize Heston where
    initialize (Heston s v0 _ _ _ _ _ _) = put (Observables [s, v0], 0)

    evolve' h@(Heston _ _ vf l rho eta _ _) t2 anti = do
        (Observables (sState:vState:_), t1) <- get
        fwd <- forwardGen h t2
        let grwth = (fwd - vState/2) * (t2-t1)
            t = t2-t1
        resid1  <- lift stdNormal
        resid2' <- lift stdNormal
        let 
          op = if anti then (-) else (+)
          resid2 = rho * resid1 + sqrt (1-rho*rho) * resid2'
          v' = (sqrt vState `op` (eta/2.0*sqrt t* resid2))^(2 :: Int)-l*(vState-vf)*t-eta*eta*t/4.0
          s' = sState * exp (grwth `op` (resid1*sqrt (vState*t)))
        put (Observables [s', v'], t2)

    discount (Heston _ _ _ _ _ _ _ d) t = disc d t

    forwardGen (Heston _ _ _ _ _ _ fg _) t2 = do
        t1 <- gets snd
        return $ forward fg t1 t2

    maxStep _ = 1/250