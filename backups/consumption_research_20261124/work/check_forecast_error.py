from datetime import timedelta

import numpy as np
from pmdarima import auto_arima

from ecotool_rolling import ACTUAL, ADJUSTMENTS, MONTHS, START


for month, days in MONTHS:
    cutoff = month - timedelta(days=1)
    size = (cutoff - START).days + 1
    history = ACTUAL[:size].copy()
    for bought, refunded, cents in ADJUSTMENTS:
        if bought <= cutoff < refunded:
            history[(bought - START).days] += cents
    history = history / 100
    for difference in (None, 0):
        model = auto_arima(history / 100, seasonal=False, information_criterion='aicc',
                           stepwise=True, start_p=0, start_q=0, max_p=2, max_q=2, max_d=2, maxiter=35,
                           suppress_warnings=True, error_action='ignore', d=difference)
        predicted = model.predict(n_periods=days) * 100
        print(month, 'd=', difference, model.order, model.with_intercept,
              model.arima_res_.param_names, model.params(), 'first last total', predicted[0], predicted[-1], sum(predicted))
    print('history last 7', history[-7:].tolist(), 'last 30 mean', np.mean(history[-30:]), 'all mean', np.mean(history))
    if month.month < 11:
        actual = ACTUAL[size:size + days] / 100
        ranked = np.argsort(actual)[-5:][::-1]
        print('actual', sum(actual), 'top', [(str(month + timedelta(days=int(index))), actual[index]) for index in ranked],
              'top 3 share', sum(actual[ranked[:3]]) / sum(actual))
