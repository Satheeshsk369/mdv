# Kalman filter

> [!NOTE]
> Predict where the system goes, then correct with what the sensor says.

## Model

The state moves linearly, with noise $w_k \sim \mathcal{N}(0, Q)$:

$$ x_k = A x_{k-1} + B u_k + w_k $$

## Update

$$ K_k = \frac{P_k H^T}{H P_k H^T + R} $$

$$ \hat{x}_k = \hat{x}_k + K_k \left( z_k - H \hat{x}_k \right) $$

| Symbol | Meaning | Size |
| :--- | :--- | ---: |
| $A$ | state transition | n × n |
| $Q$ | process noise | n × n |
| $R$ | sensor noise | m × m |

## Code

```python
x = A @ x + B @ u
P = A @ P @ A.T + Q
```

## Next

- [x] derive the gain
- [ ] add the smoother
