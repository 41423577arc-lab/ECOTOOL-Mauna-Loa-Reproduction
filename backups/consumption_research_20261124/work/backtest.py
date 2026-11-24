from collections import Counter, defaultdict
from statistics import mean

from pmdarima import auto_arima

from forecast import observations


values = [amount for _, amount in observations]
errors = defaultdict(list)
orders = Counter()
for origin in range(32, len(values) - 3):
    train = values[:origin]
    model = auto_arima(train, seasonal=False, information_criterion='aicc',
                       error_action='ignore', suppress_warnings=True)
    orders[model.order] += 1
    predicted = model.predict(n_periods=4)
    for weeks in (1, 4):
        actual = sum(values[origin:origin + weeks])
        for label, estimate in [
            ('Auto ARIMA', sum(predicted[:weeks])),
            ('historical mean', mean(train) * weeks),
            ('last week', train[-1] * weeks),
        ]:
            errors[label, weeks].append(abs(actual - estimate))
print('origins', sum(orders.values()), dict(orders))
for (label, weeks), results in errors.items():
    print(label, weeks, round(mean(results), 2))
